"""HTTP/decoder contract tests with an injected fake engine.

These tests verify validation and transport. They do NOT verify acoustic-model
accuracy, tajweed quality, or parity with any commercial app.
"""
from __future__ import annotations

import asyncio
from dataclasses import replace
import hashlib
import io
import json
import math
from pathlib import Path
import shutil
import struct
import subprocess
import tempfile
from threading import Event
import unittest
import wave

import httpx

from backend.config import MODEL_REVISION, Settings
from backend.main import create_app
from backend.reference import ReferenceRepository
from backend.schemas import Issue


def wav_bytes(duration: float = 0.5, *, silent: bool = False) -> bytes:
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as recording:
        recording.setnchannels(1)
        recording.setsampwidth(2)
        recording.setframerate(16_000)
        samples = (0 if silent else int(6000 * math.sin(2 * math.pi * 220 * n / 16_000)) for n in range(round(duration * 16_000)))
        recording.writeframes(b"".join(struct.pack("<h", sample) for sample in samples))
    return buffer.getvalue()


class FakeEngine:
    """Only a deterministic transport-test double, not a simulated quality result."""
    def __init__(self, *, ready=True, failure=False, invalid_range=False):
        self.ready = ready
        self.failure = failure
        self.invalid_range = invalid_range
        self.calls: list[str] = []
        self.entered: Event | None = None
        self.release: Event | None = None

    def assess(self, audio, reference_text):
        self.calls.append(reference_text)
        if self.entered:
            self.entered.set()
        if self.release:
            self.release.wait(timeout=5)
        if self.failure:
            raise RuntimeError("Injected contract-test failure")
        return [Issue(kind="normal", category="replace", start_scalar=0,
                      end_scalar=len(reference_text) + 1 if self.invalid_range else 1,
                      expected="TEST", observed="DOUBLE", message="Contract-test double")]


class APIContractTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="sakina-api-test-")
        self.resources = Path(self.directory.name)
        chapters = [
            {"surah_id": 1, "basmala": None, "ayahs": [{"ayah_number": 1, "text": "\ufeffبِسْمِ اللَّهِ"}, {"ayah_number": 2, "text": "الْحَمْدُ لِلَّهِ"}]},
            {"surah_id": 2, "basmala": "بِّسْمِ اللَّهِ", "ayahs": [{"ayah_number": 1, "text": "الٓمٓ"}]},
            {"surah_id": 9, "basmala": None, "ayahs": [{"ayah_number": 1, "text": "بَرَاءَةٌ"}]},
        ]
        hashes = {}
        for chapter in chapters:
            filename = f"{chapter['surah_id']:03d}.json"
            payload = json.dumps(chapter, ensure_ascii=False).encode()
            (self.resources / filename).write_bytes(payload)
            hashes[filename] = hashlib.sha256(payload).hexdigest()
        index = {"source": "quran-transcript-0.6.4", "surahs": [{"id": c["surah_id"], "count": len(c["ayahs"])} for c in chapters], "hashes": hashes}
        (self.resources / "index.json").write_text(json.dumps(index), encoding="utf-8")
        self.settings = Settings(resource_directory=self.resources)
        self.engine = FakeEngine()
        self.clients: list[httpx.AsyncClient] = []
        self.client = self.make_client()

    def make_client(self, *, settings=None, engine=None):
        client = httpx.AsyncClient(transport=httpx.ASGITransport(app=create_app(settings or self.settings, engine if engine is not None else self.engine)), base_url="http://test")
        self.clients.append(client)
        return client

    async def asyncTearDown(self):
        for client in self.clients:
            await client.aclose()
        self.directory.cleanup()

    async def post(self, *, client=None, payload=None, surah=1, ayah=2, include=False, media_type="audio/wav", extra=None, headers=None):
        data = {"surah_id": str(surah), "ayah_number": str(ayah), "include_basmala": str(include).lower()}
        data.update(extra or {})
        return await (client or self.client).post("/v1/assess", data=data, files={"audio": ("take.wav", payload if payload is not None else wav_bytes(), media_type)}, headers=headers)

    async def test_health_reports_model_and_reference_readiness(self):
        self.assertTrue((await self.client.get("/health")).json()["ready"])
        self.engine.ready = False
        result = (await self.client.get("/health")).json()
        self.assertFalse(result["ready"])
        self.assertFalse(result["model_loaded"])
        self.assertTrue(result["experimental"])

    async def test_unavailable_model_never_returns_corrections(self):
        self.engine.ready = False
        result = await self.post()
        self.assertEqual(result.status_code, 200)
        body = result.json()
        self.assertEqual(body["status"], "unavailable")
        self.assertEqual(body["issues"], [])
        self.assertEqual(body["model_revision"], MODEL_REVISION)
        self.assertEqual(body["reference_source"], "quran-transcript-0.6.4")
        self.assertNotIn("score", body)
        self.assertEqual(self.engine.calls, [])

    async def test_invalid_reference_is_rejected_before_engine(self):
        for surah, ayah in [(0, 1), (115, 1), (1, 0), (1, 3), (2, 2)]:
            self.assertEqual((await self.post(surah=surah, ayah=ayah)).status_code, 422)
        self.assertEqual(self.engine.calls, [])

    async def test_reference_is_derived_on_server_and_bom_offset_is_explicit(self):
        result = (await self.post(ayah=1, extra={"reference_text": "INJECTED TEXT"})).json()
        self.assertEqual(result["status"], "assessed")
        self.assertEqual(result["reference_text"], "بِسْمِ اللَّهِ")
        self.assertEqual(result["reference_scalar_offset"], 1)
        self.assertEqual(self.engine.calls, ["بِسْمِ اللَّهِ"])
        self.assertEqual(result["reference"], {"surah_id": 1, "ayah_number": 1})

    async def test_only_attested_opening_basmala_is_added(self):
        with_basmala = (await self.post(surah=2, ayah=1, include=True)).json()
        without = (await self.post(surah=2, ayah=1, include=False)).json()
        self.assertEqual(with_basmala["reference_text"], "بِّسْمِ اللَّهِ الٓمٓ")
        self.assertEqual(with_basmala["reference_scalar_offset"], 0)
        self.assertEqual(without["reference_text"], "الٓمٓ")
        tawba = (await self.post(surah=9, ayah=1, include=True)).json()
        self.assertEqual(tawba["reference_text"], "بَرَاءَةٌ")

    async def test_valid_contract_response_keeps_scalar_ranges(self):
        result = (await self.post()).json()
        self.assertEqual(result["status"], "assessed")
        self.assertEqual(result["schema_version"], 1)
        self.assertEqual(result["issues"][0]["start_scalar"], 0)
        self.assertEqual(result["issues"][0]["end_scalar"], 1)
        self.assertTrue(result["experimental"])

    async def test_invalid_engine_range_and_failure_do_not_become_corrections(self):
        for engine in [FakeEngine(failure=True), FakeEngine(invalid_range=True)]:
            client = self.make_client(engine=engine)
            body = (await self.post(client=client)).json()
            self.assertEqual(body["status"], "unavailable")
            self.assertEqual(body["issues"], [])

    async def test_short_and_silent_audio_are_not_scored(self):
        for payload in [wav_bytes(0.1), wav_bytes(0.6, silent=True)]:
            body = (await self.post(payload=payload)).json()
            self.assertEqual(body["status"], "insufficient_audio")
            self.assertEqual(body["issues"], [])
        self.assertEqual(self.engine.calls, [])

    async def test_duration_over_limit_is_rejected(self):
        response = await self.post(payload=wav_bytes(60.1))
        self.assertEqual(response.status_code, 415)
        self.assertEqual(self.engine.calls, [])

    async def test_unsupported_or_corrupt_audio_is_rejected(self):
        self.assertEqual((await self.post(media_type="text/plain")).status_code, 415)
        self.assertEqual((await self.post(payload=b"RIFFbad data")).status_code, 415)
        self.assertEqual(self.engine.calls, [])

    async def test_upload_size_bound_checks_actual_file_bytes(self):
        client = self.make_client(settings=replace(self.settings, max_upload_bytes=128))
        self.assertEqual((await self.post(client=client, payload=b"x" * 129)).status_code, 413)
        self.assertEqual(self.engine.calls, [])

    async def test_streamed_body_bound_does_not_require_content_length(self):
        client = self.make_client(settings=replace(self.settings, max_upload_bytes=128))
        async def body():
            yield b'--xxx\r\nContent-Disposition: form-data; name="audio"; filename="take.wav"\r\nContent-Type: audio/wav\r\n\r\n'
            yield b"x" * 40_000
            yield b"x" * 40_000
            yield b"\r\n--xxx--\r\n"
        response = await client.post("/v1/assess", content=body(), headers={"Content-Type": "multipart/form-data; boundary=xxx"})
        self.assertEqual(response.status_code, 413)
        self.assertEqual(self.engine.calls, [])

    async def test_optional_api_key_is_checked_before_parsing(self):
        client = self.make_client(settings=replace(self.settings, api_key="test-only-key"))
        self.assertEqual((await self.post(client=client)).status_code, 401)
        self.assertEqual((await self.post(client=client, headers={"X-API-Key": "wrong"})).status_code, 401)
        self.assertEqual((await self.post(client=client, headers={"X-API-Key": "test-only-key"})).status_code, 200)
        self.assertEqual((await client.get("/health")).status_code, 200)

    async def test_reference_checksum_failure_is_unavailable(self):
        (self.resources / "001.json").write_text("{}", encoding="utf-8")
        response = await self.post()
        self.assertEqual(response.status_code, 503)
        self.assertEqual(self.engine.calls, [])

    async def test_inference_is_serialized_and_does_not_block_health(self):
        self.engine.entered = Event()
        self.engine.release = Event()
        first = asyncio.create_task(self.post())
        try:
            self.assertTrue(await asyncio.to_thread(self.engine.entered.wait, 2))
            health = await asyncio.wait_for(self.client.get("/health"), timeout=0.5)
            self.assertEqual(health.status_code, 200)
            self.assertEqual((await self.post()).status_code, 429)
        finally:
            self.engine.release.set()
            response = await first
        self.assertEqual(response.status_code, 200)

    @unittest.skipUnless(shutil.which("ffmpeg"), "ffmpeg is needed for native M4A decoder verification")
    async def test_actual_m4a_decoder_removes_its_temporary_files(self):
        before = set(Path(tempfile.gettempdir()).glob("sakina-audio-*"))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            (path / "source.wav").write_bytes(wav_bytes())
            subprocess.run([shutil.which("ffmpeg"), "-nostdin", "-loglevel", "error", "-i", str(path / "source.wav"), "-c:a", "aac", str(path / "take.m4a")], check=True, capture_output=True)
            response = await self.post(payload=(path / "take.m4a").read_bytes(), media_type="audio/mp4")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["status"], "assessed")
        self.assertEqual(set(Path(tempfile.gettempdir()).glob("sakina-audio-*")), before)


if __name__ == "__main__":
    unittest.main()

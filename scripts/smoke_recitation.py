#!/usr/bin/env python3
"""Run the real pinned acoustic model through the API, without publishing a service.

Manifest: [{"path":"/local/file.m4a","surah_id":1,"ayah_number":1,
            "include_basmala":false,"source_url":"https://..."}]
No recording bytes or local filenames are written into the output report.
This checks execution and contracts, not expert-adjudicated tajweed accuracy.
"""
from __future__ import annotations

import argparse
import asyncio
import hashlib
import json
from pathlib import Path
import platform
import resource
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


async def run(manifest: Path, threads: int) -> dict:
    import httpx
    import torch
    from backend.config import MODEL_ID, MODEL_REVISION, Settings
    from backend.engine import MuaalemEngine
    from backend.main import create_app

    torch.set_num_threads(threads)
    torch.set_num_interop_threads(1)
    settings = Settings(enable_model=True, model_local_files_only=True)
    engine = MuaalemEngine(settings)
    started = time.perf_counter()
    engine.load()
    load_seconds = time.perf_counter() - started
    if not engine.ready:
        raise RuntimeError(f"Pinned model is not ready: {engine.load_error}")
    entries = json.loads(manifest.read_text(encoding="utf-8"))
    if not isinstance(entries, list) or not entries:
        raise ValueError("Supply a nonempty clip manifest")
    results = []
    app = create_app(settings, engine)
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://testserver", timeout=300) as client:
        health = (await client.get("/health")).json()
        for entry in entries:
            path = Path(entry["path"])
            payload = path.read_bytes()
            mime = "audio/wav" if path.suffix.lower() == ".wav" else "audio/mp4"
            started = time.perf_counter()
            response = await client.post("/v1/assess", data={
                "surah_id": str(entry["surah_id"]),
                "ayah_number": str(entry["ayah_number"]),
                "include_basmala": str(bool(entry.get("include_basmala", False))).lower(),
            }, files={"audio": ("recitation" + path.suffix, payload, mime)})
            elapsed = time.perf_counter() - started
            response.raise_for_status()
            assessment = response.json()
            results.append({
                "source_url": entry.get("source_url"),
                "control": entry.get("control", "reference_recitation"),
                "upload_sha256": hashlib.sha256(payload).hexdigest(),
                "upload_bytes": len(payload),
                "elapsed_seconds": round(elapsed, 3),
                "assessment": assessment,
            })
            print(f"Verse {entry['surah_id']}:{entry['ayah_number']}: {assessment['status']}, "
                  f"{len(assessment['issues'])} model indications, {elapsed:.2f}s", flush=True)
    peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
    peak_mib = peak / (1024 * 1024 if sys.platform == "darwin" else 1024)
    return {
        "verification": "Real CPU inference and in-process HTTP API execution; not expert accuracy evaluation",
        "model": MODEL_ID, "model_revision": MODEL_REVISION,
        "python": platform.python_version(), "torch": torch.__version__,
        "platform": platform.system() + " " + platform.machine(), "cpu_threads": threads,
        "model_load_seconds": round(load_seconds, 3), "peak_process_rss_mib": round(peak_mib, 1),
        "health": health, "clips": results,
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--threads", type=int, default=2, choices=range(1, 9))
    args = parser.parse_args()
    report = asyncio.run(run(args.manifest, args.threads))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Report written: {args.output}")

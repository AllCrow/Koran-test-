from __future__ import annotations

import asyncio
from contextlib import asynccontextmanager
import hmac
from typing import Annotated

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from starlette.responses import JSONResponse

from .audio import DecoderUnavailable, InsufficientAudio, InvalidAudio, decode_audio
from .config import MODEL_ID, MODEL_REVISION, Settings
from .engine import AssessmentEngine, MuaalemEngine
from .reference import ReferenceRepository, ReferenceUnavailable, ResolvedReference
from .schemas import Assessment


class RequestGuard:
    """Bound the body before multipart parsing can create spool files."""

    def __init__(self, app, *, settings: Settings):
        self.app = app
        self.settings = settings

    async def __call__(self, scope, receive, send):
        if scope["type"] != "http" or scope.get("path") != "/v1/assess":
            return await self.app(scope, receive, send)
        headers = dict(scope.get("headers", []))
        if self.settings.api_key:
            supplied = headers.get(b"x-api-key", b"")
            if not hmac.compare_digest(supplied, self.settings.api_key.encode("utf-8")):
                return await JSONResponse({"detail": "API-nyckeln saknas eller är felaktig."}, status_code=401)(scope, receive, send)
        limit = self.settings.max_upload_bytes + 64 * 1024
        try:
            content_length = int(headers.get(b"content-length", b"0"))
        except ValueError:
            content_length = 0
        if content_length > limit:
            return await JSONResponse({"detail": "Ljudfilen är för stor."}, status_code=413)(scope, receive, send)
        # Buffer only a bounded body. Raising from receive mid-multipart makes
        # Starlette turn the limit into a 400 and can strand its spool file.
        body = bytearray()
        while True:
            message = await receive()
            if message["type"] == "http.disconnect":
                return
            chunk = message.get("body", b"")
            if len(body) + len(chunk) > limit:
                return await JSONResponse({"detail": "Ljudfilen är för stor."}, status_code=413)(scope, receive, send)
            body.extend(chunk)
            if not message.get("more_body", False):
                break
        replayed = False

        async def replay_receive():
            nonlocal replayed
            if not replayed:
                replayed = True
                return {"type": "http.request", "body": bytes(body), "more_body": False}
            return await receive()

        await self.app(scope, replay_receive, send)


def create_app(settings: Settings | None = None, engine: AssessmentEngine | None = None) -> FastAPI:
    settings = settings or Settings.from_env()
    active_engine = engine if engine is not None else MuaalemEngine(settings)
    references = ReferenceRepository(settings.resource_directory)
    analysis_lock = asyncio.Lock()

    @asynccontextmanager
    async def lifespan(_app: FastAPI):
        if engine is None and settings.enable_model:
            await asyncio.to_thread(active_engine.load)
        yield

    app = FastAPI(title="Sakina Experimental Recitation Analysis", version="0.1.0", lifespan=lifespan)
    app.add_middleware(RequestGuard, settings=settings)
    app.state.engine = active_engine

    @app.get("/health")
    async def health():
        ready = active_engine.ready and references.available
        return {
            "ready": ready,
            "status": "ready" if ready else "unavailable",
            "model_loaded": active_engine.ready,
            "experimental": True,
            "model": MODEL_ID,
            "model_revision": MODEL_REVISION,
            "reference_source": references.source,
        }

    def response(reference: ResolvedReference, *, status: str, message: str, issues=None) -> Assessment:
        return Assessment(
            status=status,
            reference=reference.identifier,
            reference_text=reference.text,
            reference_source=references.source,
            reference_scalar_offset=reference.scalar_offset,
            include_basmala=reference.include_basmala,
            issues=issues or [],
            message=message,
        )

    def process(payload: bytes, reference: ResolvedReference) -> Assessment:
        try:
            decoded = decode_audio(payload, settings)
            issues = active_engine.assess(decoded, reference.text)
            for issue in issues:
                if not (0 <= issue.start_scalar <= issue.end_scalar <= len(reference.text)):
                    raise ValueError("Invalid engine range")
            return response(reference, status="assessed", issues=issues, message=(
                "Experimentell analys klar. Gå igenom markeringarna med en kunnig lärare."
                if issues else "Den fonetiska jämförelsen hittade inga skillnader. Resultatet är experimentellt och behöver lärarbedömning."
            ))
        except InsufficientAudio as error:
            return response(reference, status="insufficient_audio", message=str(error))
        except DecoderUnavailable as error:
            return response(reference, status="unavailable", message=str(error))
        except InvalidAudio as error:
            raise HTTPException(status_code=415, detail=str(error)) from error
        except Exception:
            return response(reference, status="unavailable", message="Analysmotorn kunde inte bedöma inspelningen. Inga rättningar visas.")

    @app.post("/v1/assess", response_model=Assessment)
    async def assess(
        audio: Annotated[UploadFile, File()],
        surah_id: Annotated[int, Form()],
        ayah_number: Annotated[int, Form()],
        include_basmala: Annotated[bool, Form()] = False,
    ):
        try:
            reference = references.resolve(surah_id, ayah_number, include_basmala=include_basmala)
        except ValueError as error:
            raise HTTPException(status_code=422, detail="Ogiltig sura eller vers.") from error
        except ReferenceUnavailable as error:
            raise HTTPException(status_code=503, detail="Referenstexten är inte tillgänglig på servern.") from error
        media_type = (audio.content_type or "application/octet-stream").split(";", 1)[0].lower()
        if media_type not in {"audio/mp4", "audio/m4a", "audio/x-m4a", "audio/aac", "audio/wav", "audio/x-wav", "audio/wave", "application/octet-stream"}:
            await audio.close()
            raise HTTPException(status_code=415, detail="Använd en M4A- eller WAV-inspelning.")
        try:
            payload = await audio.read(settings.max_upload_bytes + 1)
        finally:
            await audio.close()
        if len(payload) > settings.max_upload_bytes:
            raise HTTPException(status_code=413, detail="Ljudfilen är för stor.")
        if not active_engine.ready:
            return response(reference, status="unavailable", message="Den experimentella analysmodellen är inte laddad på servern. Inga rättningar visas.")
        if analysis_lock.locked():
            raise HTTPException(status_code=429, detail="Servern analyserar redan en inspelning. Försök igen strax.")
        async with analysis_lock:
            job = asyncio.create_task(asyncio.to_thread(process, payload, reference))
            try:
                return await asyncio.shield(job)
            except asyncio.CancelledError:
                # A thread cannot be cancelled with its HTTP task. Keep the
                # slot until it ends, including if shutdown cancels us again.
                while not job.done():
                    try:
                        await asyncio.shield(job)
                    except asyncio.CancelledError:
                        continue
                    except Exception:
                        break
                if not job.cancelled():
                    # Retrieve a worker exception without replacing the
                    # caller's cancellation or leaving an unhandled task.
                    job.exception()
                raise

    return app


app = create_app()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("backend.main:app", host="127.0.0.1", port=8000, access_log=False, limit_concurrency=4)

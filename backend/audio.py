from __future__ import annotations

from array import array
from dataclasses import dataclass
import io
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import wave

from .config import Settings

SAMPLE_RATE = 16_000


class InvalidAudio(ValueError):
    pass


class InsufficientAudio(ValueError):
    pass


class DecoderUnavailable(RuntimeError):
    pass


@dataclass
class DecodedAudio:
    samples: array
    sample_rate: int = SAMPLE_RATE

    @property
    def duration(self) -> float:
        return len(self.samples) / self.sample_rate


def _pcm16_samples(raw: bytes) -> array:
    if len(raw) % 2:
        raise InvalidAudio("Ljudfilen innehåller ofullständiga PCM-data.")
    integers = array("h")
    integers.frombytes(raw)
    if sys.byteorder != "little":
        integers.byteswap()
    return array("f", (sample / 32768.0 for sample in integers))


def _input_format(payload: bytes) -> str:
    """Select one self-contained supported container before invoking ffmpeg.

    Do not let ffmpeg autodetect playlists, concat scripts or other formats
    that can refer to files outside the uploaded recording.
    """
    if len(payload) >= 12 and payload[:4] == b"RIFF" and payload[8:12] == b"WAVE":
        return "wav"
    if len(payload) >= 16 and payload[4:8] == b"ftyp":
        return "mov"
    # ADTS sync word and zero layer bits. The decoder validates the complete
    # header and frames; a content-type supplied by the client is not trusted.
    if len(payload) >= 7 and payload[0] == 0xFF and (payload[1] & 0xF6) == 0xF0:
        return "aac"
    raise InvalidAudio("Använd en M4A- eller WAV-inspelning med giltigt filinnehåll.")


def decode_audio(payload: bytes, settings: Settings) -> DecodedAudio:
    """Decode a bounded local file. No recording or filename is logged/retained."""
    input_format = _input_format(payload)
    raw: bytes | None = None
    used_decoder = False
    if input_format == "wav":
        try:
            with wave.open(io.BytesIO(payload), "rb") as recording:
                if recording.getcomptype() == "NONE" and recording.getnchannels() == 1 and recording.getsampwidth() == 2 and recording.getframerate() == SAMPLE_RATE:
                    if recording.getnframes() > settings.max_duration_seconds * SAMPLE_RATE:
                        raise InvalidAudio("Inspelningen får vara högst 60 sekunder.")
                    expected_bytes = recording.getnframes() * 2
                    raw = recording.readframes(recording.getnframes())
                    if len(raw) != expected_bytes:
                        raise InvalidAudio("Ljudfilen är ofullständig. Spela in frasen igen.")
        except (wave.Error, EOFError) as error:
            raise InvalidAudio("Ljudfilen kunde inte läsas.") from error
    if raw is None:
        used_decoder = True
        executable = shutil.which(settings.ffmpeg_binary)
        if executable is None:
            raise DecoderUnavailable("Ljudavkodaren saknas på servern. Använd PCM WAV, mono, 16 kHz.")
        with tempfile.TemporaryDirectory(prefix="sakina-audio-") as directory:
            source = Path(directory) / "input.audio"
            source.write_bytes(payload)
            # MOV normally disables external track references. Keep that
            # boundary explicit even if ffmpeg's defaults change.
            container_options = ["-enable_drefs", "0", "-use_absolute_path", "0"] if input_format == "mov" else []
            try:
                result = subprocess.run(
                    [executable, "-nostdin", "-hide_banner", "-loglevel", "error",
                     "-protocol_whitelist", "file,pipe", "-f", input_format, *container_options, "-i", str(source),
                     "-map", "0:a:0", "-vn", "-sn", "-dn",
                     "-ac", "1", "-ar", str(SAMPLE_RATE),
                     "-t", str(settings.max_duration_seconds + 0.1),
                     "-f", "s16le", "-acodec", "pcm_s16le", "pipe:1"],
                    stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=20, check=False,
                )
            except (OSError, subprocess.TimeoutExpired) as error:
                raise InvalidAudio("Ljudfilen kunde inte avkodas inom tidsgränsen.") from error
            if result.returncode != 0:
                raise InvalidAudio("Ljudfilen kunde inte avkodas.")
            raw = result.stdout
    audio = DecodedAudio(_pcm16_samples(raw))
    if audio.duration > settings.max_duration_seconds:
        maximum_samples = int(settings.max_duration_seconds * SAMPLE_RATE)
        # Resampling a native 44.1 kHz/AAC take of exactly 60 seconds can
        # produce a handful of tail samples (six observed with ffmpeg).
        # Discard at most 1 ms of decoder roundoff; native PCM remains strict
        # and genuinely longer recordings are still rejected.
        if used_decoder and len(audio.samples) <= maximum_samples + SAMPLE_RATE // 1000:
            del audio.samples[maximum_samples:]
        else:
            raise InvalidAudio("Inspelningen får vara högst 60 sekunder.")
    if audio.duration < settings.min_duration_seconds:
        raise InsufficientAudio("Inspelningen är för kort. Läs en hel fras och försök igen.")
    rms = math.sqrt(sum(sample * sample for sample in audio.samples) / len(audio.samples))
    if rms < 0.0008:
        raise InsufficientAudio("Inspelningen är för tyst för att analysera. Försök igen nära mikrofonen.")
    return audio

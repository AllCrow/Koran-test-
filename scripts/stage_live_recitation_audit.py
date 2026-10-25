#!/usr/bin/env python3
"""Stage the opt-in live iOS audit into an ephemeral CI checkout, not the app.

No network or recording input here. Pin the expected public-source bytes and
source-code hashes from the committed audit. Normal project inputs stay intact
until this explicit staging command is run.
"""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest = ROOT / "docs/evidence/recitation-source-audit-2026-10-25.json"
    report = json.loads(manifest.read_bytes())
    if not report["passed"] or report["errors"]:
        raise ValueError("The source audit is not passing")
    if report["app_source_sha256"] != digest(ROOT / "Sources/QuranCore/Models.swift"):
        raise ValueError("Review the changed production reciter configuration first")
    target = ROOT / "AppTests/EveryAyahLiveSourceTests.swift"
    if target.exists():
        raise ValueError("Refusing to overwrite an existing test file")
    template = (ROOT / "Verification/EveryAyahLiveSourceTests.swift").read_text()
    substitutions = {
        "__SOURCE_COMMIT__": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "__MANIFEST_SHA256__": digest(manifest),
    }
    # Storage admission now lives outside AudioLibrary, and the player uses the
    # shared finite-loop contract. Include both implementations in the emitted
    # fingerprints rather than pinning only their callers.
    code = {p: digest(ROOT / p) for p in [
        "App/Services/AudioLibrary.swift",
        "App/Services/AudioFileDownloader.swift",
        "App/Services/AudioStorageInventory.swift",
        "App/Services/RecitationPlayer.swift",
        "Sources/QuranCore/Models.swift",
        "Sources/QuranCore/RecitationLoop.swift",
    ]}
    # Escape a JSON string for its single Swift string literal.
    substitutions["__CODE_SHA256_JSON__"] = json.dumps(code, sort_keys=True).replace('\\', '\\\\').replace('"', '\\"')
    for reciter in ("alafasy", "husary", "minshawi"):
        sample, = [x for x in report["samples"] if x["app_reciter"] == reciter
                   and (x["surah_id"], x["ayah_number"]) == (112, 2)]
        substitutions[f"__{reciter.upper()}_SHA256__"] = sample["sha256"]
        substitutions[f"__{reciter.upper()}_BYTES__"] = str(sample["bytes"])
    for token, value in substitutions.items():
        if token not in template:
            raise ValueError(f"Missing template marker: {token}")
        template = template.replace(token, value)
    if "__" in template:
        raise ValueError("Unresolved audit template marker")
    target.write_text(template)
    print("Staged three opt-in live-source tests; no production source was changed.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Verify shipped font provenance and native app resource declarations, without extra packages."""
import hashlib
from pathlib import Path
import plistlib
import struct

ROOT = Path(__file__).resolve().parents[1]
EXPECTED = {
    "AmiriQuran-Regular.ttf": "e2a47644762d16bdfb6d33e0d8db8c6ff30beae84150ef5a705316bbd829455c",
    "OFL.txt": "72de68e5954f4fdd24702292ef5a32f003ca960ec9330dc86e5eefb5dffb9b22",
}


def main():
    font_dir = ROOT / "App/Resources/Fonts"
    for filename, expected in EXPECTED.items():
        assert hashlib.sha256((font_dir / filename).read_bytes()).hexdigest() == expected, filename
    info = plistlib.loads((ROOT / "App/Info.plist").read_bytes())
    for declared_font in info["UIAppFonts"]:
        assert (ROOT / "App/Resources" / declared_font).is_file(), declared_font
    assert info["NSMicrophoneUsageDescription"]
    assert "audio" in info["UIBackgroundModes"]
    privacy = plistlib.loads((ROOT / "App/PrivacyInfo.xcprivacy").read_bytes())
    assert privacy["NSPrivacyTracking"] is False
    assert privacy["NSPrivacyCollectedDataTypes"] == []
    icon = (ROOT / "App/Assets.xcassets/AppIcon.appiconset/AppIcon.png").read_bytes()
    assert icon[:8] == b"\x89PNG\r\n\x1a\n"
    width, height, bits, color = struct.unpack(">IIBB", icon[16:26])
    assert (width, height, bits, color) == (1024, 1024, 8, 2), "App icon must be opaque 1024px RGB"
    print("Verified font hashes, native resource declarations, privacy manifest and opaque 1024px icon")


if __name__ == "__main__":
    main()

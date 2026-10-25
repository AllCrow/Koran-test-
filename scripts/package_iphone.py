#!/usr/bin/env python3
"""Verify a physical-iPhone build and package it for subsequent personal signing.

Runs on macOS after xcodebuild with CODE_SIGNING_ALLOWED=NO. No Apple account,
certificate or provisioning profile is consumed by this script.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import zipfile


def command(*arguments):
    return subprocess.check_output(arguments, text=True, stderr=subprocess.STDOUT).strip()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    arguments = parser.parse_args()
    app = arguments.app.resolve(strict=True)
    if not app.is_dir() or app.suffix != ".app":
        raise SystemExit("Expected a built .app directory")
    info = plistlib.loads((app / "Info.plist").read_bytes())
    executable_name = info.get("CFBundleExecutable", "")
    if not executable_name or Path(executable_name).name != executable_name:
        raise SystemExit("Invalid app executable name")
    executable = app / executable_name
    architectures = command("xcrun", "lipo", "-archs", str(executable)).split()
    build_info = command("xcrun", "vtool", "-show-build", str(executable))
    platforms = re.findall(r"^\s*platform\s+(\S+)", build_info, re.MULTILINE)
    if not architectures or any(arch not in {"arm64", "arm64e"} for arch in architectures):
        raise SystemExit("The executable must contain only physical-iPhone architectures")
    if not platforms or any(platform.upper() != "IOS" for platform in platforms):
        raise SystemExit("Expected iPhoneOS binaries; a simulator app cannot be sideloaded")
    if info.get("DTPlatformName") != "iphoneos":
        raise SystemExit("The app's plist does not declare an iPhoneOS build")
    if "iPhoneOS" not in info.get("CFBundleSupportedPlatforms", []) or 1 not in info.get("UIDeviceFamily", []):
        raise SystemExit("The app must support physical iPhone devices")
    if list(app.rglob("embedded.mobileprovision")):
        raise SystemExit("This artifact must not contain a developer provisioning profile")
    if list(app.rglob("*.xctest")):
        raise SystemExit("Test bundles must not be included in a personal app")
    required_resources = ["PrivacyInfo.xcprivacy", "Quran/index.json", "Fonts/AmiriQuran-Regular.ttf"]
    required_resources.extend(f"Quran/{number:03}.json" for number in range(1, 115))
    if any(not (app / name).is_file() for name in required_resources):
        raise SystemExit("The app is missing required offline reading resources")
    if not list(app.glob("*.bundle/PracticeReferences/index.json")):
        raise SystemExit("The app is missing its practice reference bundle")
    embedded_binaries = set(app.rglob("*.dylib"))
    for framework in app.rglob("*.framework"):
        framework_info = framework / "Info.plist"
        if not framework_info.is_file():
            raise SystemExit(f"Framework metadata is missing: {framework.name}")
        framework_executable = plistlib.loads(framework_info.read_bytes()).get("CFBundleExecutable", "")
        if not framework_executable or Path(framework_executable).name != framework_executable:
            raise SystemExit(f"Invalid framework executable: {framework.name}")
        embedded_binaries.add(framework / framework_executable)
    for binary in sorted(embedded_binaries):
        binary_architectures = command("xcrun", "lipo", "-archs", str(binary)).split()
        binary_info = command("xcrun", "vtool", "-show-build", str(binary))
        binary_platforms = re.findall(r"^\s*platform\s+(\S+)", binary_info, re.MULTILINE)
        if not binary_architectures or any(arch not in {"arm64", "arm64e"} for arch in binary_architectures):
            raise SystemExit(f"Non-iPhone architecture in embedded binary: {binary.name}")
        if not binary_platforms or any(platform.upper() != "IOS" for platform in binary_platforms):
            raise SystemExit(f"Non-iPhone platform in embedded binary: {binary.name}")

    output = arguments.output.resolve()
    report = arguments.report.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    report.parent.mkdir(parents=True, exist_ok=True)
    # macOS zip preserves executable permissions and framework symlinks (-y).
    # Stage in a temporary directory so no build data enters the source tree.
    with tempfile.TemporaryDirectory(prefix="sakina-iphone-") as directory:
        temporary = Path(directory)
        payload = temporary / "Payload"
        payload.mkdir()
        shutil.copytree(app, payload / app.name, symlinks=True)
        packed = temporary / "personal.ipa"
        subprocess.run(["/usr/bin/zip", "-q", "-y", "-r", str(packed), "Payload"], cwd=temporary, check=True)
        with zipfile.ZipFile(packed) as archive:
            if archive.testzip() is not None:
                raise SystemExit("IPA archive integrity check failed")
            if f"Payload/{app.name}/Info.plist" not in archive.namelist():
                raise SystemExit("IPA is missing its application payload")
        shutil.copyfile(packed, output)
    metadata = {
        "bundle_identifier": info["CFBundleIdentifier"],
        "minimum_ios": info.get("MinimumOSVersion"),
        "platform": "iPhoneOS",
        "architectures": architectures,
        "configuration": "Release",
        "app_version": info.get("CFBundleShortVersionString"),
        "build_number": info.get("CFBundleVersion"),
        "embedded_binaries_verified": len(embedded_binaries),
        "source_commit": os.environ.get("GITHUB_SHA"),
        "ipa_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "ipa_bytes": output.stat().st_size,
        "requires_personal_signing_and_device_provisioning": True,
        "direct_install_from_safari": False,
        "physical_iphone_tested": False,
        "note": "Prepared for personal signing. This is not a signed or installable TestFlight release.",
    }
    report.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    print(f"Verified iPhoneOS/{','.join(architectures)} and packaged {output.name}; personal signing is still required.")


if __name__ == "__main__":
    main()

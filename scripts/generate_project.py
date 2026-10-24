#!/usr/bin/env python3
"""Generate a dependency-free Xcode app project around the local QuranCore package."""
from pathlib import Path
import hashlib
import json
import plistlib

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "Sakina.xcodeproj"


def identifier(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()


def quoted(value):
    return json.dumps(str(value))


def generate():
    objects = []

    def add(object_name, kind, **fields):
        lines = [f"\t\t{identifier(object_name)} = {{", f"\t\t\tisa = {kind};"]
        for key, value in fields.items():
            lines.append(f"\t\t\t{key} = {value};")
        lines.append("\t\t};")
        objects.append("\n".join(lines))
        return identifier(object_name)

    def items(values):
        return "(" + ", ".join(values) + ")"

    def settings(values):
        return "{ " + " ".join(f"{key} = {quoted(value)};" for key, value in values.items()) + " }"

    swift_files = sorted((ROOT / "App").rglob("*.swift"))
    sources = []
    source_refs = []
    for file in swift_files:
        path = file.relative_to(ROOT).as_posix()
        ref = add("ref:" + path, "PBXFileReference", lastKnownFileType="sourcecode.swift", path=quoted(path), sourceTree=quoted("<group>"))
        source_refs.append(ref)
        sources.append(add("build:" + path, "PBXBuildFile", fileRef=ref))

    resources = []
    resource_refs = []
    for path, file_type in [("App/Resources/Quran", "folder"), ("App/Resources/Fonts", "folder"), ("App/PrivacyInfo.xcprivacy", "text.xml"), ("App/Assets.xcassets", "folder.assetcatalog")]:
        ref = add("ref:" + path, "PBXFileReference", lastKnownFileType=quoted(file_type), path=quoted(path), sourceTree=quoted("<group>"))
        resource_refs.append(ref)
        resources.append(add("build:" + path, "PBXBuildFile", fileRef=ref))

    product_ref = add("product", "PBXFileReference", explicitFileType="wrapper.application", includeInIndex="0", path=quoted("Sakina.app"), sourceTree="BUILT_PRODUCTS_DIR")
    info_ref = add("info", "PBXFileReference", lastKnownFileType="text.plist.xml", path=quoted("App/Info.plist"), sourceTree=quoted("<group>"))
    source_group = add("sources", "PBXGroup", children=items(source_refs), name=quoted("App"), sourceTree=quoted("<group>"))
    resource_group = add("resources", "PBXGroup", children=items(resource_refs + [info_ref]), name=quoted("Resources"), sourceTree=quoted("<group>"))
    product_group = add("products", "PBXGroup", children=items([product_ref]), name=quoted("Products"), sourceTree=quoted("<group>"))
    main_group = add("main", "PBXGroup", children=items([source_group, resource_group, product_group]), sourceTree=quoted("<group>"))

    local_package = add("package", "XCLocalSwiftPackageReference", relativePath=quoted("."))
    package_products = []
    package_builds = []
    for product in ["QuranCore", "QuranData", "QuranPractice"]:
        dependency = add("packageProduct:" + product, "XCSwiftPackageProductDependency", package=local_package, productName=quoted(product))
        package_products.append(dependency)
        package_builds.append(add("packageBuild:" + product, "PBXBuildFile", productRef=dependency))
    source_phase = add("sourcePhase", "PBXSourcesBuildPhase", buildActionMask="2147483647", files=items(sources), runOnlyForDeploymentPostprocessing="0")
    resources_phase = add("resourcesPhase", "PBXResourcesBuildPhase", buildActionMask="2147483647", files=items(resources), runOnlyForDeploymentPostprocessing="0")
    frameworks_phase = add("frameworksPhase", "PBXFrameworksBuildPhase", buildActionMask="2147483647", files=items(package_builds), runOnlyForDeploymentPostprocessing="0")

    project_settings = {
        "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES",
        "IPHONEOS_DEPLOYMENT_TARGET": "17.0", "SDKROOT": "iphoneos",
        "SWIFT_VERSION": "5.0", "ENABLE_USER_SCRIPT_SANDBOXING": "YES",
        "SWIFT_STRICT_CONCURRENCY": "minimal"
    }
    app_settings = {
        "PRODUCT_NAME": "$(TARGET_NAME)", "PRODUCT_BUNDLE_IDENTIFIER": "org.example.Sakina",
        "INFOPLIST_FILE": "App/Info.plist", "GENERATE_INFOPLIST_FILE": "NO",
        "CODE_SIGN_STYLE": "Automatic", "TARGETED_DEVICE_FAMILY": "1",
        "SUPPORTS_MACCATALYST": "NO", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator",
        "MARKETING_VERSION": "0.1.0", "CURRENT_PROJECT_VERSION": "1",
        "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
        "LD_RUNPATH_SEARCH_PATHS": "$(inherited) @executable_path/Frameworks"
    }
    configs = {}
    for owner, base in [("project", project_settings), ("app", app_settings)]:
        entries = []
        for mode in ["Debug", "Release"]:
            values = dict(base)
            if owner == "project":
                values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if mode == "Debug" else "-O",
                               "DEBUG_INFORMATION_FORMAT": "dwarf" if mode == "Debug" else "dwarf-with-dsym"})
                if mode == "Debug":
                    values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "$(inherited) DEBUG"
                    values["ENABLE_TESTABILITY"] = "YES"
            entries.append(add(owner + mode, "XCBuildConfiguration", buildSettings=settings(values), name=quoted(mode)))
        configs[owner] = add(owner + "Config", "XCConfigurationList", buildConfigurations=items(entries), defaultConfigurationIsVisible="0", defaultConfigurationName=quoted("Release"))

    target = add("target", "PBXNativeTarget", buildConfigurationList=configs["app"], buildPhases=items([source_phase, frameworks_phase, resources_phase]), buildRules="()", dependencies="()", name=quoted("Sakina"), packageProductDependencies=items(package_products), productName=quoted("Sakina"), productReference=product_ref, productType=quoted("com.apple.product-type.application"))
    project = add("projectRoot", "PBXProject", attributes="{ BuildIndependentTargetsInParallel = YES; LastUpgradeCheck = 1600; }", buildConfigurationList=configs["project"], compatibilityVersion=quoted("Xcode 14.0"), developmentRegion=quoted("sv"), hasScannedForEncodings="0", knownRegions=items([quoted("sv"), quoted("en"), quoted("ar"), quoted("Base")]), mainGroup=main_group, packageReferences=items([local_package]), productRefGroup=product_group, projectDirPath=quoted(""), projectRoot=quoted(""), targets=items([target]))

    PROJECT.mkdir(exist_ok=True)
    (PROJECT / "project.pbxproj").write_text("// !$*UTF8*$!\n{\n\tarchiveVersion = 1;\n\tclasses = {};\n\tobjectVersion = 56;\n\tobjects = {\n" + "\n".join(objects) + "\n\t};\n\trootObject = " + project + ";\n}\n")
    schemes = PROJECT / "xcshareddata/xcschemes"
    schemes.mkdir(parents=True, exist_ok=True)
    scheme = f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="1600" version="1.3">
  <BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES">
    <BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">
      <BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Sakina.app" BlueprintName="Sakina" ReferencedContainer="container:Sakina.xcodeproj"/>
    </BuildActionEntry></BuildActionEntries>
  </BuildAction>
  <LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES">
    <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Sakina.app" BlueprintName="Sakina" ReferencedContainer="container:Sakina.xcodeproj"/></BuildableProductRunnable>
  </LaunchAction>
  <ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES">
    <BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="Sakina.app" BlueprintName="Sakina" ReferencedContainer="container:Sakina.xcodeproj"/></BuildableProductRunnable>
  </ProfileAction>
  <AnalyzeAction buildConfiguration="Debug"/>
  <ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>
'''
    (schemes / "Sakina.xcscheme").write_text(scheme)
    workspace = PROJECT / "project.xcworkspace"
    workspace.mkdir(exist_ok=True)
    (workspace / "contents.xcworkspacedata").write_text('<?xml version="1.0" encoding="UTF-8"?><Workspace version="1.0"><FileRef location="self:"/></Workspace>\n')
    print(f"Generated {PROJECT.name}: {len(swift_files)} Swift files + {len(package_products)} local libraries")


if __name__ == "__main__":
    generate()

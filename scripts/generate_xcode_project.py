#!/usr/bin/env python3
"""Generate the dependency-free iOS project using stable PBX identifiers."""
import hashlib
import json
import plistlib
from pathlib import Path

root = Path(__file__).resolve().parents[1]
ios = root / "ios"
project = ios / "CampusEvents.xcodeproj"
project.mkdir(exist_ok=True)
objects = {}

def uid(name):
    return hashlib.sha1(name.encode()).hexdigest()[:24].upper()

def add(name, value):
    key = uid(name)
    objects[key] = value
    return key

def ref(path, kind):
    return add(path, {"isa": "PBXFileReference", "lastKnownFileType": kind, "path": path, "sourceTree": "<group>"})

def phase(name, isa, files):
    return add(name, {"isa": isa, "buildActionMask": "2147483647", "files": files, "runOnlyForDeploymentPostprocessing": "0"})

def buildfile(path, file_id):
    return add("build:" + path, {"isa": "PBXBuildFile", "fileRef": file_id})

sources, resources, app_files, test_files, test_sources = [], [], [], [], []
for p in sorted((ios / "CampusEvents").glob("*.swift")):
    path = str(p.relative_to(ios))
    f = ref(path, "sourcecode.swift"); app_files.append(f); sources.append(buildfile(path, f))
# Original source posters live in Resources; bundled variants use the asset catalog.
asset = "CampusEvents/Assets.xcassets"
if (ios / asset).exists():
    f = ref(asset, "folder.assetcatalog"); app_files.append(f); resources.append(buildfile(asset, f))
for p in sorted((ios / "CampusEventsTests").glob("*.swift")):
    path = str(p.relative_to(ios)); f = ref(path, "sourcecode.swift"); test_files.append(f); test_sources.append(buildfile(path, f))
app_product = add("app-product", {"isa": "PBXFileReference", "explicitFileType": "wrapper.application", "path": "CampusEvents.app", "sourceTree": "BUILT_PRODUCTS_DIR"})
test_product = add("test-product", {"isa": "PBXFileReference", "explicitFileType": "wrapper.cfbundle", "path": "CampusEventsTests.xctest", "sourceTree": "BUILT_PRODUCTS_DIR"})
products = add("products", {"isa": "PBXGroup", "children": [app_product, test_product], "name": "Products", "sourceTree": "<group>"})
app_group = add("app-files", {"isa": "PBXGroup", "children": app_files, "name": "CampusEvents", "sourceTree": "<group>"})
tests_group = add("test-files", {"isa": "PBXGroup", "children": test_files, "name": "Tests", "sourceTree": "<group>"})
main = add("main", {"isa": "PBXGroup", "children": [app_group, tests_group, products], "sourceTree": "<group>"})

base = {"SDKROOT": "iphoneos", "IPHONEOS_DEPLOYMENT_TARGET": "18.0", "SWIFT_VERSION": "5.0", "CLANG_ENABLE_MODULES": "YES", "CLANG_ENABLE_OBJC_ARC": "YES", "SWIFT_STRICT_CONCURRENCY": "targeted", "ENABLE_USER_SCRIPT_SANDBOXING": "YES", "TARGETED_DEVICE_FAMILY": "1", "SUPPORTED_PLATFORMS": "iphoneos iphonesimulator"}

def config_list(name, settings):
    ids = []
    for variant in ("Debug", "Release"):
        values = dict(settings)
        values.update({"SWIFT_OPTIMIZATION_LEVEL": "-Onone" if variant == "Debug" else "-O", "DEBUG_INFORMATION_FORMAT": "dwarf" if variant == "Debug" else "dwarf-with-dsym", "ENABLE_TESTABILITY": "YES" if variant == "Debug" else "NO"})
        if variant == "Debug": values["SWIFT_ACTIVE_COMPILATION_CONDITIONS"] = "DEBUG"
        ids.append(add(name + variant, {"isa": "XCBuildConfiguration", "buildSettings": values, "name": variant}))
    return add(name + "configs", {"isa": "XCConfigurationList", "buildConfigurations": ids, "defaultConfigurationIsVisible": "0", "defaultConfigurationName": "Release"})

project_configs = config_list("project", base)
app_settings = {"PRODUCT_NAME": "CampusEvents", "PRODUCT_BUNDLE_IDENTIFIER": "cn.huodongjun.campus", "INFOPLIST_FILE": "CampusEvents/Info.plist", "CODE_SIGN_STYLE": "Automatic", "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon", "MARKETING_VERSION": "0.4.0", "CURRENT_PROJECT_VERSION": "5", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"]}
test_settings = {"PRODUCT_NAME": "CampusEventsTests", "PRODUCT_BUNDLE_IDENTIFIER": "cn.huodongjun.campus.tests", "GENERATE_INFOPLIST_FILE": "YES", "TEST_HOST": "$(BUILT_PRODUCTS_DIR)/CampusEvents.app/$(BUNDLE_EXECUTABLE_FOLDER_PATH)/CampusEvents", "BUNDLE_LOADER": "$(TEST_HOST)", "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks", "@loader_path/Frameworks"]}
app_target = add("app-target", {"isa": "PBXNativeTarget", "name": "CampusEvents", "productName": "CampusEvents", "productReference": app_product, "productType": "com.apple.product-type.application", "buildConfigurationList": config_list("app", app_settings), "buildPhases": [phase("app-sources", "PBXSourcesBuildPhase", sources), phase("app-frameworks", "PBXFrameworksBuildPhase", []), phase("app-resources", "PBXResourcesBuildPhase", resources)], "buildRules": [], "dependencies": []})
proxy = add("proxy", {"isa": "PBXContainerItemProxy", "containerPortal": uid("project"), "proxyType": "1", "remoteGlobalIDString": app_target, "remoteInfo": "CampusEvents"})
dep = add("test-dependency", {"isa": "PBXTargetDependency", "target": app_target, "targetProxy": proxy})
test_target = add("test-target", {"isa": "PBXNativeTarget", "name": "CampusEventsTests", "productName": "CampusEventsTests", "productReference": test_product, "productType": "com.apple.product-type.bundle.unit-test", "buildConfigurationList": config_list("test", test_settings), "buildPhases": [phase("test-sources", "PBXSourcesBuildPhase", test_sources), phase("test-frameworks", "PBXFrameworksBuildPhase", [])], "buildRules": [], "dependencies": [dep]})
project_id = add("project", {"isa": "PBXProject", "attributes": {"LastUpgradeCheck": "2600"}, "buildConfigurationList": project_configs, "compatibilityVersion": "Xcode 14.0", "developmentRegion": "zh_CN", "knownRegions": ["zh_CN", "en", "Base"], "mainGroup": main, "productRefGroup": products, "projectDirPath": "", "projectRoot": "", "targets": [app_target, test_target]})

def encode(value, level=0):
    if isinstance(value, dict):
        return "{\n" + "".join("\t" * (level + 1) + json.dumps(k) + " = " + encode(v, level + 1) + ";\n" for k, v in value.items()) + "\t" * level + "}"
    if isinstance(value, list): return "(" + ", ".join(encode(x, level) for x in value) + ")"
    return json.dumps(value, ensure_ascii=False)

(project / "project.pbxproj").write_text("// !$*UTF8*$!\n" + encode({"archiveVersion": "1", "classes": {}, "objectVersion": "56", "objects": objects, "rootObject": project_id}) + "\n")
scheme_dir = project / "xcshareddata/xcschemes"
scheme_dir.mkdir(parents=True, exist_ok=True)
def buildable(target, name):
    return f'<BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="{name}" BlueprintName="{name.split(".")[0]}" ReferencedContainer="container:CampusEvents.xcodeproj"/>'
(scheme_dir / "CampusEvents.xcscheme").write_text(f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES">{buildable(app_target, 'CampusEvents.app')}</BuildActionEntry></BuildActionEntries></BuildAction>
<TestAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES"><Testables><TestableReference skipped="NO">{buildable(test_target, 'CampusEventsTests.xctest')}</TestableReference></Testables></TestAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(app_target, 'CampusEvents.app')}</BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"><BuildableProductRunnable runnableDebuggingMode="0">{buildable(app_target, 'CampusEvents.app')}</BuildableProductRunnable></ProfileAction>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>''')

info = {"CFBundleDisplayName": "活动君", "CFBundleName": "$(PRODUCT_NAME)", "CFBundleIdentifier": "$(PRODUCT_BUNDLE_IDENTIFIER)", "CFBundleExecutable": "$(EXECUTABLE_NAME)", "CFBundlePackageType": "APPL", "CFBundleShortVersionString": "$(MARKETING_VERSION)", "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)", "LSRequiresIPhoneOS": True, "UILaunchScreen": {}, "UIApplicationSceneManifest": {"UIApplicationSupportsMultipleScenes": False}, "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"], "NSCameraUsageDescription": "拍摄活动图片或头像，以及扫描入场凭证完成现场签到。", "NSPhotoLibraryAddUsageDescription": "将你选择保存的活动群二维码添加到相册。", "NSCalendarsWriteOnlyAccessUsageDescription": "将你选择的活动加入系统日历。", "LSApplicationQueriesSchemes": ["weixin", "mqq"]}
(ios / "CampusEvents/Info.plist").write_bytes(plistlib.dumps(info))
print("Generated", project)

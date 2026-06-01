#!/usr/bin/env python3
"""Generates present2md.xcodeproj — a minimal Xcode app project that
wraps present2mdApp/ sources and depends on the local present2mdCore SPM package."""

import os, textwrap

ROOT = "/Users/razhari/tmp/present2md"
PROJ = os.path.join(ROOT, "present2md.xcodeproj")
WS   = os.path.join(PROJ, "project.xcworkspace")

# ── Deterministic object IDs ─────────────────────────────────────────────────
R = {
    "root":            "AA000001000000000000000A",
    "main_group":      "AA000001000000000000000B",
    "src_group":       "AA000001000000000000000C",
    "fw_group":        "AA000001000000000000000D",
    "prod_group":      "AA000001000000000000000E",
    "target":          "AA000001000000000000001A",
    "src_phase":       "AA000001000000000000001B",
    "res_phase":       "AA000001000000000000001C",
    "fw_phase":        "AA000001000000000000001D",
    "proj_cfglist":    "AA000001000000000000002A",
    "proj_debug":      "AA000001000000000000002B",
    "proj_release":    "AA000001000000000000002C",
    "tgt_cfglist":     "AA000001000000000000002D",
    "tgt_debug":       "AA000001000000000000002E",
    "tgt_release":     "AA000001000000000000002F",
    # source file refs
    "ref_app":         "AA000001000000000000003A",
    "ref_content":     "AA000001000000000000003B",
    "ref_empty":       "AA000001000000000000003C",
    "ref_filelist":    "AA000001000000000000003D",
    "ref_filerow":     "AA000001000000000000003E",
    "ref_timeout":     "AA000001000000000000003F",
    "ref_assets":      "AA000001000000000000004A",
    "ref_infoplist":   "AA000001000000000000004B",
    "ref_product":     "AA000001000000000000004C",
    # build file entries
    "bf_app":          "AA000001000000000000005A",
    "bf_content":      "AA000001000000000000005B",
    "bf_empty":        "AA000001000000000000005C",
    "bf_filelist":     "AA000001000000000000005D",
    "bf_filerow":      "AA000001000000000000005E",
    "bf_timeout":      "AA000001000000000000005F",
    "bf_assets":       "AA000001000000000000006A",
    # SPM
    "pkg_ref":         "AA000001000000000000007A",
    "pkg_dep":         "AA000001000000000000007B",
    "bf_pkgcore":      "AA000001000000000000007C",
}

SOURCE_FILES = [
    ("ref_app",      "bf_app",      "present2mdApp.swift"),
    ("ref_content",  "bf_content",  "ContentView.swift"),
    ("ref_empty",    "bf_empty",    "EmptyStateView.swift"),
    ("ref_filelist", "bf_filelist", "FileListView.swift"),
    ("ref_filerow",  "bf_filerow",  "FileRowView.swift"),
    ("ref_timeout",  "bf_timeout",  "TimeoutAlertView.swift"),
]

def pbxproj():
    src_file_refs = "\n".join(
        f'\t\t{R[ref]} = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; '
        f'name = "{name}"; path = "present2mdApp/{name}"; sourceTree = "<group>"; }};'
        for ref, _, name in SOURCE_FILES
    )
    src_build_files = "\n".join(
        f'\t\t{R[bf]} = {{isa = PBXBuildFile; fileRef = {R[ref]}; }};'
        for ref, bf, _ in SOURCE_FILES
    )
    src_phase_files = " ".join(f"{R[bf]}," for _, bf, _ in SOURCE_FILES)
    src_group_children = " ".join(f"{R[ref]}," for ref, _, _ in SOURCE_FILES)

    common_settings = """\
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_STYLE = Automatic;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.9;"""

    release_settings = """\
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				CODE_SIGN_STYLE = Automatic;
				COPY_PHASE_STRIP = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_C_LANGUAGE_STANDARD = gnu17;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.9;"""

    tgt_debug = """\
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				BUNDLE_LOADER = "";
				CODE_SIGN_ENTITLEMENTS = "";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				INFOPLIST_FILE = "present2mdApp/Info.plist";
				LD_RUNPATH_SEARCH_PATHS = "@executable_path/../Frameworks";
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = "com.rakhmad.present2md";
				PRODUCT_NAME = present2md;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.9;"""

    tgt_release = tgt_debug.replace(
        "CURRENT_PROJECT_VERSION = 1;",
        "CURRENT_PROJECT_VERSION = 1;\n\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = \"-O\";"
    )

    return textwrap.dedent(f"""\
// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 60;
\tobjects = {{

/* Begin PBXBuildFile section */
{src_build_files}
\t\t{R["bf_assets"]} = {{isa = PBXBuildFile; fileRef = {R["ref_assets"]}; }};
\t\t{R["bf_pkgcore"]} = {{isa = PBXBuildFile; productRef = {R["pkg_dep"]}; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{src_file_refs}
\t\t{R["ref_assets"]} = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = "Assets.xcassets"; path = "present2mdApp/Assets.xcassets"; sourceTree = "<group>"; }};
\t\t{R["ref_infoplist"]} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = "Info.plist"; path = "present2mdApp/Info.plist"; sourceTree = "<group>"; }};
\t\t{R["ref_product"]} = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "present2md.app"; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{R["fw_phase"]} = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{R["bf_pkgcore"]},
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{R["main_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{R["src_group"]},
\t\t\t\t{R["fw_group"]},
\t\t\t\t{R["prod_group"]},
\t\t\t);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{R["src_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{src_group_children}
\t\t\t\t{R["ref_assets"]},
\t\t\t\t{R["ref_infoplist"]},
\t\t\t);
\t\t\tname = "present2mdApp";
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{R["fw_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ();
\t\t\tname = Frameworks;
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{R["prod_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{R["ref_product"]},
\t\t\t);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{R["target"]} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {R["tgt_cfglist"]};
\t\t\tbuildPhases = (
\t\t\t\t{R["src_phase"]},
\t\t\t\t{R["fw_phase"]},
\t\t\t\t{R["res_phase"]},
\t\t\t);
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tname = present2md;
\t\t\tpackageProductDependencies = (
\t\t\t\t{R["pkg_dep"]},
\t\t\t);
\t\t\tproductName = present2md;
\t\t\tproductReference = {R["ref_product"]};
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{R["root"]} = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1500;
\t\t\t\tLastUpgradeCheck = 1500;
\t\t\t}};
\t\t\tbuildConfigurationList = {R["proj_cfglist"]};
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (en, Base);
\t\t\tmainGroup = {R["main_group"]};
\t\t\tpackageReferences = (
\t\t\t\t{R["pkg_ref"]},
\t\t\t);
\t\t\tproductRefGroup = {R["prod_group"]};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t{R["target"]},
\t\t\t);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{R["res_phase"]} = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{R["bf_assets"]},
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{R["src_phase"]} = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t\t{src_phase_files}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{R["proj_debug"]} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{common_settings}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{R["proj_release"]} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{release_settings}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
\t\t{R["tgt_debug"]} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{tgt_debug}
\t\t\t}};
\t\t\tname = Debug;
\t\t}};
\t\t{R["tgt_release"]} = {{
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {{
{tgt_release}
\t\t\t}};
\t\t\tname = Release;
\t\t}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{R["proj_cfglist"]} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({R["proj_debug"]}, {R["proj_release"]}, );
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
\t\t{R["tgt_cfglist"]} = {{
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = ({R["tgt_debug"]}, {R["tgt_release"]}, );
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t}};
/* End XCConfigurationList section */

/* Begin XCLocalSwiftPackageReference section */
\t\t{R["pkg_ref"]} = {{
\t\t\tisa = XCLocalSwiftPackageReference;
\t\t\trelativePath = ".";
\t\t}};
/* End XCLocalSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
\t\t{R["pkg_dep"]} = {{
\t\t\tisa = XCSwiftPackageProductDependency;
\t\t\tpackage = {R["pkg_ref"]};
\t\t\tproductName = present2mdCore;
\t\t}};
/* End XCSwiftPackageProductDependency section */

\t}};
\trootObject = {R["root"]};
}}
""")

def workspace_data():
    return textwrap.dedent("""\
<?xml version="1.0" encoding="UTF-8"?>
<Workspace version = "1.0">
  <FileRef location = "self:">
  </FileRef>
</Workspace>
""")

if __name__ == "__main__":
    os.makedirs(WS, exist_ok=True)
    with open(os.path.join(PROJ, "project.pbxproj"), "w") as f:
        f.write(pbxproj())
    with open(os.path.join(WS, "contents.xcworkspacedata"), "w") as f:
        f.write(workspace_data())
    print(f"Generated {PROJ}")
    print("Open present2md.xcodeproj in Xcode, select the 'present2md' scheme, and run.")

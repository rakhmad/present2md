#!/usr/bin/env python3
"""Generates present2md.xcodeproj — a macOS app target that compiles
present2md/ (core) and present2mdApp/ (UI) together, linking ZIPFoundation
via a remote SPM dependency. No local package reference needed."""

import os, textwrap

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROJ = os.path.join(ROOT, "present2md.xcodeproj")
WS   = os.path.join(PROJ, "project.xcworkspace")

# ── Object IDs ────────────────────────────────────────────────────────────────
def uid(n): return f"AA{n:022X}"

R = {
    "root":          uid(1),
    "main_group":    uid(2),
    "core_group":    uid(3),
    "app_group":     uid(4),
    "fw_group":      uid(5),
    "prod_group":    uid(6),
    "target":        uid(0x10),
    "src_phase":     uid(0x11),
    "res_phase":     uid(0x12),
    "fw_phase":      uid(0x13),
    "proj_cfglist":  uid(0x20),
    "proj_debug":    uid(0x21),
    "proj_release":  uid(0x22),
    "tgt_cfglist":   uid(0x23),
    "tgt_debug":     uid(0x24),
    "tgt_release":   uid(0x25),
    "ref_assets":    uid(0x40),
    "ref_infoplist": uid(0x41),
    "ref_product":   uid(0x42),
    "bf_assets":     uid(0x50),
    "pkg_ref":       uid(0x60),  # XCRemoteSwiftPackageReference
    "pkg_dep":       uid(0x61),  # XCSwiftPackageProductDependency
    "bf_zip":        uid(0x62),  # build file for ZIPFoundation
}

# Core library source files
CORE_FILES = [
    ("Converters/FileConverter.swift",),
    ("Converters/ODSConverter.swift",),
    ("Converters/PDFConverter.swift",),
    ("Converters/PPTXConverter.swift",),
    ("Coordinator/ConversionCoordinator.swift",),
    ("Model/ConversionJob.swift",),
    ("Model/Slide.swift",),
    ("Model/SlideBlock.swift",),
    ("Serializer/MarkdownSerializer.swift",),
    ("Utilities/FilenameConverter.swift",),
]

# App layer source files
APP_FILES = [
    ("present2mdApp.swift",),
    ("ContentView.swift",),
    ("EmptyStateView.swift",),
    ("FileListView.swift",),
    ("FileRowView.swift",),
    ("TimeoutAlertView.swift",),
]

# Assign UIDs to each file
for i, row in enumerate(CORE_FILES):
    base = 0x100 + i
    R[f"core_ref_{i}"] = uid(base)
    R[f"core_bf_{i}"]  = uid(base + 0x80)

for i, row in enumerate(APP_FILES):
    base = 0x200 + i
    R[f"app_ref_{i}"] = uid(base)
    R[f"app_bf_{i}"]  = uid(base + 0x80)


def pbxproj():
    # ── File references ────────────────────────────────────────────────────
    core_refs = "\n".join(
        f'\t\t{R[f"core_ref_{i}"]} = {{isa = PBXFileReference; '
        f'lastKnownFileType = sourcecode.swift; '
        f'name = "{row[0].split("/")[-1]}"; '
        f'path = "present2md/{row[0]}"; sourceTree = "<group>"; }};'
        for i, row in enumerate(CORE_FILES)
    )
    app_refs = "\n".join(
        f'\t\t{R[f"app_ref_{i}"]} = {{isa = PBXFileReference; '
        f'lastKnownFileType = sourcecode.swift; '
        f'name = "{row[0]}"; '
        f'path = "present2mdApp/{row[0]}"; sourceTree = "<group>"; }};'
        for i, row in enumerate(APP_FILES)
    )

    # ── Build files ────────────────────────────────────────────────────────
    core_bfs = "\n".join(
        f'\t\t{R[f"core_bf_{i}"]} = {{isa = PBXBuildFile; fileRef = {R[f"core_ref_{i}"]}; }};'
        for i in range(len(CORE_FILES))
    )
    app_bfs = "\n".join(
        f'\t\t{R[f"app_bf_{i}"]} = {{isa = PBXBuildFile; fileRef = {R[f"app_ref_{i}"]}; }};'
        for i in range(len(APP_FILES))
    )

    # ── Phase file lists ───────────────────────────────────────────────────
    all_src_bfs = (
        " ".join(f"{R[f'core_bf_{i}']}," for i in range(len(CORE_FILES))) + "\n\t\t\t\t" +
        " ".join(f"{R[f'app_bf_{i}']}," for i in range(len(APP_FILES)))
    )

    # ── Group children ─────────────────────────────────────────────────────
    core_children = " ".join(f"{R[f'core_ref_{i}']}," for i in range(len(CORE_FILES)))
    app_children  = " ".join(f"{R[f'app_ref_{i}']}," for i in range(len(APP_FILES)))

    tgt_settings = """\
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
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

    proj_debug = """\
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = DEBUG;
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.9;"""

    proj_release = """\
				ALWAYS_SEARCH_USER_PATHS = NO;
				CLANG_ENABLE_MODULES = YES;
				GCC_NO_COMMON_BLOCKS = YES;
				MACOSX_DEPLOYMENT_TARGET = 13.0;
				SWIFT_OPTIMIZATION_LEVEL = "-O";
				SWIFT_VERSION = 5.9;"""

    return textwrap.dedent(f"""\
// !$*UTF8*$!
{{
\tarchiveVersion = 1;
\tclasses = {{
\t}};
\tobjectVersion = 60;
\tobjects = {{

/* Begin PBXBuildFile section */
{core_bfs}
{app_bfs}
\t\t{R["bf_assets"]} = {{isa = PBXBuildFile; fileRef = {R["ref_assets"]}; }};
\t\t{R["bf_zip"]}    = {{isa = PBXBuildFile; productRef = {R["pkg_dep"]}; }};
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{core_refs}
{app_refs}
\t\t{R["ref_assets"]}    = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; name = "Assets.xcassets"; path = "present2mdApp/Assets.xcassets"; sourceTree = "<group>"; }};
\t\t{R["ref_infoplist"]} = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; name = "Info.plist"; path = "present2mdApp/Info.plist"; sourceTree = "<group>"; }};
\t\t{R["ref_product"]}   = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = "present2md.app"; sourceTree = BUILT_PRODUCTS_DIR; }};
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t{R["fw_phase"]} = {{
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({R["bf_zip"]},);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
\t\t{R["main_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({R["core_group"]}, {R["app_group"]}, {R["fw_group"]}, {R["prod_group"]},);
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{R["core_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({core_children});
\t\t\tname = "present2md (Core)";
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{R["app_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({app_children} {R["ref_assets"]}, {R["ref_infoplist"]},);
\t\t\tname = "present2mdApp";
\t\t\tsourceTree = "<group>";
\t\t}};
\t\t{R["fw_group"]}   = {{isa = PBXGroup; children = (); name = Frameworks; sourceTree = "<group>"; }};
\t\t{R["prod_group"]} = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = ({R["ref_product"]},);
\t\t\tname = Products;
\t\t\tsourceTree = "<group>";
\t\t}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t{R["target"]} = {{
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = {R["tgt_cfglist"]};
\t\t\tbuildPhases = ({R["src_phase"]}, {R["fw_phase"]}, {R["res_phase"]},);
\t\t\tbuildRules = ();
\t\t\tdependencies = ();
\t\t\tname = present2md;
\t\t\tpackageProductDependencies = ({R["pkg_dep"]},);
\t\t\tproductName = present2md;
\t\t\tproductReference = {R["ref_product"]};
\t\t\tproductType = "com.apple.product-type.application";
\t\t}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t{R["root"]} = {{
\t\t\tisa = PBXProject;
\t\t\tattributes = {{BuildIndependentTargetsInParallel = 1; LastSwiftUpdateCheck = 1500; LastUpgradeCheck = 1500; }};
\t\t\tbuildConfigurationList = {R["proj_cfglist"]};
\t\t\tcompatibilityVersion = "Xcode 14.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (en, Base);
\t\t\tmainGroup = {R["main_group"]};
\t\t\tpackageReferences = ({R["pkg_ref"]},);
\t\t\tproductRefGroup = {R["prod_group"]};
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = ({R["target"]},);
\t\t}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t{R["res_phase"]} = {{
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({R["bf_assets"]},);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t{R["src_phase"]} = {{
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = ({all_src_bfs});
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t{R["proj_debug"]}   = {{isa = XCBuildConfiguration; buildSettings = {{{proj_debug}\n\t\t\t}}; name = Debug; }};
\t\t{R["proj_release"]} = {{isa = XCBuildConfiguration; buildSettings = {{{proj_release}\n\t\t\t}}; name = Release; }};
\t\t{R["tgt_debug"]}    = {{isa = XCBuildConfiguration; buildSettings = {{{tgt_settings}\n\t\t\t}}; name = Debug; }};
\t\t{R["tgt_release"]}  = {{isa = XCBuildConfiguration; buildSettings = {{{tgt_settings}\n\t\t\t}}; name = Release; }};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t{R["proj_cfglist"]} = {{isa = XCConfigurationList; buildConfigurations = ({R["proj_debug"]}, {R["proj_release"]},); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
\t\t{R["tgt_cfglist"]}  = {{isa = XCConfigurationList; buildConfigurations = ({R["tgt_debug"]},  {R["tgt_release"]}, ); defaultConfigurationIsVisible = 0; defaultConfigurationName = Release; }};
/* End XCConfigurationList section */

/* Begin XCRemoteSwiftPackageReference section */
\t\t{R["pkg_ref"]} = {{
\t\t\tisa = XCRemoteSwiftPackageReference;
\t\t\trepositoryURL = "https://github.com/weichsel/ZIPFoundation.git";
\t\t\trequirement = {{kind = upToNextMajorVersion; minimumVersion = "0.9.19"; }};
\t\t}};
/* End XCRemoteSwiftPackageReference section */

/* Begin XCSwiftPackageProductDependency section */
\t\t{R["pkg_dep"]} = {{isa = XCSwiftPackageProductDependency; package = {R["pkg_ref"]}; productName = ZIPFoundation; }};
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
    print("Open present2md.xcodeproj, select the 'present2md' scheme, Cmd+R.")

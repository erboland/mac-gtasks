#!/usr/bin/env python3
import os

ids = {
    "project": "A1B2C3D4E5F60718293A0001",
    "appTarget": "A1B2C3D4E5F60718293A0002",
    "widgetTarget": "A1B2C3D4E5F60718293A0003",
    "appProduct": "A1B2C3D4E5F60718293A0004",
    "widgetProduct": "A1B2C3D4E5F60718293A0005",
    "appSources": "A1B2C3D4E5F60718293A0006",
    "appResources": "A1B2C3D4E5F60718293A0007",
    "appFrameworks": "A1B2C3D4E5F60718293A0008",
    "appEmbed": "A1B2C3D4E5F60718293A0009",
    "widgetSources": "A1B2C3D4E5F60718293A000A",
    "widgetResources": "A1B2C3D4E5F60718293A000B",
    "widgetFrameworks": "A1B2C3D4E5F60718293A000C",
    "mainGroup": "A1B2C3D4E5F60718293A000D",
    "productsGroup": "A1B2C3D4E5F60718293A000E",
    "tasksGroup": "A1B2C3D4E5F60718293A000F",
    "widgetGroup": "A1B2C3D4E5F60718293A0010",
    "sharedGroup": "A1B2C3D4E5F60718293A0011",
    "proxy": "A1B2C3D4E5F60718293A0012",
    "dep": "A1B2C3D4E5F60718293A0013",
    "embedBuild": "A1B2C3D4E5F60718293A0014",
    "appConfigList": "A1B2C3D4E5F60718293A0015",
    "widgetConfigList": "A1B2C3D4E5F60718293A0016",
    "projectConfigList": "A1B2C3D4E5F60718293A0017",
    "appDebug": "A1B2C3D4E5F60718293A0018",
    "appRelease": "A1B2C3D4E5F60718293A0019",
    "widgetDebug": "A1B2C3D4E5F60718293A001A",
    "widgetRelease": "A1B2C3D4E5F60718293A001B",
    "projectDebug": "A1B2C3D4E5F60718293A001C",
    "projectRelease": "A1B2C3D4E5F60718293A001D",
}

shared_files = [
    "AppGroup.swift",
    "Models.swift",
    "GoogleAuthConfig.swift",
    "KeychainStore.swift",
    "SharedStore.swift",
    "ListColor.swift",
    "DateFormatting.swift",
    "SampleData.swift",
    "TokenManager.swift",
    "GoogleTasksClient.swift",
    "SyncService.swift",
    "TaskIntents.swift",
    "RemindersChrome.swift",
]

app_files = [
    "TasksApp.swift",
    "SessionController.swift",
    "ContentView.swift",
    "SidebarView.swift",
    "TaskListView.swift",
    "TaskRowView.swift",
    "GoogleOAuth.swift",
]

widget_files = [
    "TasksWidget.swift",
    "TasksWidgetBundle.swift",
]

file_refs = {}
build_files = {}
n = 0x20


def next_id():
    global n
    n += 1
    return f"A1B2C3D4E5F60718293A00{n:02X}"


for f in shared_files:
    file_refs[f"shared/{f}"] = next_id()
    build_files[f"app/{f}"] = next_id()
    build_files[f"widget/{f}"] = next_id()

for f in app_files:
    file_refs[f"app/{f}"] = next_id()
    build_files[f"app/{f}"] = next_id()

for f in widget_files:
    file_refs[f"widget/{f}"] = next_id()
    build_files[f"widget/{f}"] = next_id()

file_refs["app/assets"] = next_id()
file_refs["app/entitlements"] = next_id()
file_refs["app/info"] = next_id()
file_refs["widget/assets"] = next_id()
file_refs["widget/entitlements"] = next_id()
file_refs["widget/info"] = next_id()
build_files["app/assets"] = next_id()
build_files["widget/assets"] = next_id()

build_file_section = []
for f in shared_files:
    build_file_section.append(
        f"\t\t{build_files[f'app/{f}']} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f'shared/{f}']} /* {f} */; }};"
    )
    build_file_section.append(
        f"\t\t{build_files[f'widget/{f}']} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f'shared/{f}']} /* {f} */; }};"
    )
for f in app_files:
    build_file_section.append(
        f"\t\t{build_files[f'app/{f}']} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f'app/{f}']} /* {f} */; }};"
    )
for f in widget_files:
    build_file_section.append(
        f"\t\t{build_files[f'widget/{f}']} /* {f} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[f'widget/{f}']} /* {f} */; }};"
    )
build_file_section.append(
    f"\t\t{build_files['app/assets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs['app/assets']} /* Assets.xcassets */; }};"
)
build_file_section.append(
    f"\t\t{build_files['widget/assets']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {file_refs['widget/assets']} /* Assets.xcassets */; }};"
)
build_file_section.append(
    f"\t\t{ids['embedBuild']} /* TasksWidget.appex in Embed Foundation Extensions */ = {{isa = PBXBuildFile; fileRef = {ids['widgetProduct']} /* TasksWidget.appex */; settings = {{ATTRIBUTES = (RemoveHeadersOnCopy, ); }}; }};"
)

file_ref_section = []
for f in shared_files:
    file_ref_section.append(
        f'\t\t{file_refs[f"shared/{f}"]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};'
    )
for f in app_files:
    file_ref_section.append(
        f'\t\t{file_refs[f"app/{f}"]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};'
    )
for f in widget_files:
    file_ref_section.append(
        f'\t\t{file_refs[f"widget/{f}"]} /* {f} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {f}; sourceTree = "<group>"; }};'
    )

file_ref_section.append(
    f"\t\t{ids['appProduct']} /* Tasks.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Tasks.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
)
file_ref_section.append(
    f'\t\t{ids["widgetProduct"]} /* TasksWidget.appex */ = {{isa = PBXFileReference; explicitFileType = "wrapper.app-extension"; includeInIndex = 0; path = TasksWidget.appex; sourceTree = BUILT_PRODUCTS_DIR; }};'
)
file_ref_section.append(
    f'\t\t{file_refs["app/assets"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};'
)
file_ref_section.append(
    f'\t\t{file_refs["app/entitlements"]} /* Tasks.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = Tasks.entitlements; sourceTree = "<group>"; }};'
)
file_ref_section.append(
    f'\t\t{file_refs["app/info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};'
)
file_ref_section.append(
    f'\t\t{file_refs["widget/assets"]} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = "<group>"; }};'
)
file_ref_section.append(
    f'\t\t{file_refs["widget/entitlements"]} /* TasksWidget.entitlements */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.entitlements; path = TasksWidget.entitlements; sourceTree = "<group>"; }};'
)
file_ref_section.append(
    f'\t\t{file_refs["widget/info"]} /* Info.plist */ = {{isa = PBXFileReference; lastKnownFileType = text.plist.xml; path = Info.plist; sourceTree = "<group>"; }};'
)

shared_children = "\n".join(f"\t\t\t\t{file_refs[f'shared/{f}']} /* {f} */," for f in shared_files)
app_children = "\n".join(f"\t\t\t\t{file_refs[f'app/{f}']} /* {f} */," for f in app_files)
widget_children = "\n".join(f"\t\t\t\t{file_refs[f'widget/{f}']} /* {f} */," for f in widget_files)

app_sources = "\n".join(
    [f"\t\t\t\t{build_files[f'app/{f}']} /* {f} in Sources */," for f in app_files]
    + [f"\t\t\t\t{build_files[f'app/{f}']} /* {f} in Sources */," for f in shared_files]
)
widget_sources = "\n".join(
    [f"\t\t\t\t{build_files[f'widget/{f}']} /* {f} in Sources */," for f in widget_files]
    + [f"\t\t\t\t{build_files[f'widget/{f}']} /* {f} in Sources */," for f in shared_files]
)

pbx = f'''// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{chr(10).join(build_file_section)}
/* End PBXBuildFile section */

/* Begin PBXContainerItemProxy section */
		{ids['proxy']} /* PBXContainerItemProxy */ = {{
			isa = PBXContainerItemProxy;
			containerPortal = {ids['project']} /* Project object */;
			proxyType = 1;
			remoteGlobalIDString = {ids['widgetTarget']};
			remoteInfo = TasksWidget;
		}};
/* End PBXContainerItemProxy section */

/* Begin PBXCopyFilesBuildPhase section */
		{ids['appEmbed']} /* Embed Foundation Extensions */ = {{
			isa = PBXCopyFilesBuildPhase;
			buildActionMask = 2147483647;
			dstPath = "";
			dstSubfolderSpec = 13;
			files = (
				{ids['embedBuild']} /* TasksWidget.appex in Embed Foundation Extensions */,
			);
			name = "Embed Foundation Extensions";
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXCopyFilesBuildPhase section */

/* Begin PBXFileReference section */
{chr(10).join(file_ref_section)}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{ids['appFrameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['widgetFrameworks']} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{ids['mainGroup']} = {{
			isa = PBXGroup;
			children = (
				{ids['tasksGroup']} /* Tasks */,
				{ids['widgetGroup']} /* TasksWidget */,
				{ids['sharedGroup']} /* Shared */,
				{ids['productsGroup']} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{ids['productsGroup']} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{ids['appProduct']} /* Tasks.app */,
				{ids['widgetProduct']} /* TasksWidget.appex */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{ids['tasksGroup']} /* Tasks */ = {{
			isa = PBXGroup;
			children = (
{app_children}
				{file_refs['app/assets']} /* Assets.xcassets */,
				{file_refs['app/entitlements']} /* Tasks.entitlements */,
				{file_refs['app/info']} /* Info.plist */,
			);
			path = Tasks;
			sourceTree = "<group>";
		}};
		{ids['widgetGroup']} /* TasksWidget */ = {{
			isa = PBXGroup;
			children = (
{widget_children}
				{file_refs['widget/assets']} /* Assets.xcassets */,
				{file_refs['widget/entitlements']} /* TasksWidget.entitlements */,
				{file_refs['widget/info']} /* Info.plist */,
			);
			path = TasksWidget;
			sourceTree = "<group>";
		}};
		{ids['sharedGroup']} /* Shared */ = {{
			isa = PBXGroup;
			children = (
{shared_children}
			);
			path = Shared;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{ids['appTarget']} /* Tasks */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['appConfigList']} /* Build configuration list for PBXNativeTarget "Tasks" */;
			buildPhases = (
				{ids['appSources']} /* Sources */,
				{ids['appFrameworks']} /* Frameworks */,
				{ids['appResources']} /* Resources */,
				{ids['appEmbed']} /* Embed Foundation Extensions */,
			);
			buildRules = (
			);
			dependencies = (
				{ids['dep']} /* PBXTargetDependency */,
			);
			name = Tasks;
			productName = Tasks;
			productReference = {ids['appProduct']} /* Tasks.app */;
			productType = "com.apple.product-type.application";
		}};
		{ids['widgetTarget']} /* TasksWidget */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {ids['widgetConfigList']} /* Build configuration list for PBXNativeTarget "TasksWidget" */;
			buildPhases = (
				{ids['widgetSources']} /* Sources */,
				{ids['widgetFrameworks']} /* Frameworks */,
				{ids['widgetResources']} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = TasksWidget;
			productName = TasksWidget;
			productReference = {ids['widgetProduct']} /* TasksWidget.appex */;
			productType = "com.apple.product-type.app-extension";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{ids['project']} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1540;
				LastUpgradeCheck = 1540;
				TargetAttributes = {{
					{ids['appTarget']} = {{
						CreatedOnToolsVersion = 15.4;
					}};
					{ids['widgetTarget']} = {{
						CreatedOnToolsVersion = 15.4;
					}};
				}};
			}};
			buildConfigurationList = {ids['projectConfigList']} /* Build configuration list for PBXProject "Tasks" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {ids['mainGroup']};
			productRefGroup = {ids['productsGroup']} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{ids['appTarget']} /* Tasks */,
				{ids['widgetTarget']} /* TasksWidget */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{ids['appResources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{build_files['app/assets']} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['widgetResources']} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{build_files['widget/assets']} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{ids['appSources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{app_sources}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
		{ids['widgetSources']} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{widget_sources}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin PBXTargetDependency section */
		{ids['dep']} /* PBXTargetDependency */ = {{
			isa = PBXTargetDependency;
			target = {ids['widgetTarget']} /* TasksWidget */;
			targetProxy = {ids['proxy']} /* PBXContainerItemProxy */;
		}};
/* End PBXTargetDependency section */

/* Begin XCBuildConfiguration section */
		{ids['projectDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = macosx;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{ids['projectRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				SDKROOT = macosx;
				SWIFT_COMPILATION_MODE = wholemodule;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{ids['appDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Tasks/Tasks.entitlements;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Tasks/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Tasks;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.googletasks.Tasks;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{ids['appRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_ENTITLEMENTS = Tasks/Tasks.entitlements;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				COMBINE_HIDPI_IMAGES = YES;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = Tasks/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Tasks;
				INFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.productivity";
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.googletasks.Tasks;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
		{ids['widgetDebug']} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_ENTITLEMENTS = TasksWidget/TasksWidget.entitlements;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = TasksWidget/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Tasks;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@executable_path/../../../../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.googletasks.Tasks.Widget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Debug;
		}};
		{ids['widgetRelease']} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{
				CODE_SIGN_ENTITLEMENTS = TasksWidget/TasksWidget.entitlements;
				CODE_SIGN_IDENTITY = "Apple Development";
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				ENABLE_HARDENED_RUNTIME = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_FILE = TasksWidget/Info.plist;
				INFOPLIST_KEY_CFBundleDisplayName = Tasks;
				INFOPLIST_KEY_NSHumanReadableCopyright = "";
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/../Frameworks",
					"@executable_path/../../../../Frameworks",
				);
				MACOSX_DEPLOYMENT_TARGET = 14.0;
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.googletasks.Tasks.Widget;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SKIP_INSTALL = YES;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{ids['projectConfigList']} /* Build configuration list for PBXProject "Tasks" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['projectDebug']} /* Debug */,
				{ids['projectRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['appConfigList']} /* Build configuration list for PBXNativeTarget "Tasks" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['appDebug']} /* Debug */,
				{ids['appRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{ids['widgetConfigList']} /* Build configuration list for PBXNativeTarget "TasksWidget" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{ids['widgetDebug']} /* Debug */,
				{ids['widgetRelease']} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {ids['project']} /* Project object */;
}}
'''

path = os.path.join(os.path.dirname(__file__), "..", "Tasks.xcodeproj", "project.pbxproj")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as handle:
    handle.write(pbx)
print("wrote", os.path.abspath(path), "bytes", os.path.getsize(path))

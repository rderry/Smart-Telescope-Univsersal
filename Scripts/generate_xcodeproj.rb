#!/usr/bin/env ruby

require "digest"
require "fileutils"

PROJECT_NAME = "AstronomyObservationPlanning"
APP_PRODUCT_NAME = "Smart Scope Observation Planner"
APP_BUNDLE_ID = "com.bigskyastro.SmartScopeObservationPlanner"
ROOT = File.expand_path("..", __dir__)
PROJECT_DIR = File.join(ROOT, "#{PROJECT_NAME}.xcodeproj")
PBXPROJ_PATH = File.join(PROJECT_DIR, "project.pbxproj")
WORKSPACE_PATH = File.join(PROJECT_DIR, "project.xcworkspace", "contents.xcworkspacedata")
SCHEME_PATH = File.join(PROJECT_DIR, "xcshareddata", "xcschemes", "#{PROJECT_NAME}.xcscheme")

def uuid(key)
  Digest::MD5.hexdigest(key).upcase[0, 24]
end

def file_type(path)
  return "folder.assetcatalog" if path.end_with?(".xcassets")

  case File.extname(path)
  when ".swift"
    "sourcecode.swift"
  when ".json"
    "text.json"
  when ".jpg", ".jpeg"
    "image.jpeg"
  when ".entitlements"
    "text.plist.entitlements"
  when ".md"
    "net.daringfireball.markdown"
  else
    "text"
  end
end

def quote(value)
  value.include?(" ") ? "\"#{value}\"" : value
end

app_files = ["Sources/AstronomyObservationPlanningApp.swift"]
model_files = Dir.chdir(ROOT) { Dir["Sources/Models/*.swift"].sort }
service_files = Dir.chdir(ROOT) { Dir["Sources/Services/*.swift"].sort }
view_files = Dir.chdir(ROOT) { Dir["Sources/Views/*.swift"].sort }
resource_files = Dir.chdir(ROOT) do
  Dir["Sources/Resources/*"].sort.select { |path| File.file?(path) || path.end_with?(".xcassets") }
end
support_files = [
  "AstronomyObservationPlanning.entitlements",
  "AppSandboxChecklist.md",
  "Package.swift"
]

all_source_files = app_files + model_files + service_files + view_files

groups = {
  main: uuid("group:main"),
  products: uuid("group:products"),
  sources: uuid("group:sources"),
  models: uuid("group:models"),
  services: uuid("group:services"),
  views: uuid("group:views"),
  resources: uuid("group:resources"),
  support: uuid("group:support")
}

product_ref = uuid("file:product")
target_id = uuid("target:app")
project_id = uuid("project:root")
sources_phase_id = uuid("phase:sources")
frameworks_phase_id = uuid("phase:frameworks")
resources_phase_id = uuid("phase:resources")
project_config_list_id = uuid("configlist:project")
target_config_list_id = uuid("configlist:target")
project_debug_config_id = uuid("config:project:debug")
project_release_config_id = uuid("config:project:release")
target_debug_config_id = uuid("config:target:debug")
target_release_config_id = uuid("config:target:release")

file_ref_ids = {}
build_file_ids = {}

(all_source_files + resource_files + support_files).each do |path|
  file_ref_ids[path] = uuid("file:#{path}")
end

(all_source_files + resource_files).each do |path|
  build_file_ids[path] = uuid("build:#{path}")
end

pbx_build_file_lines = []
all_source_files.each do |path|
  pbx_build_file_lines << "\t\t#{build_file_ids[path]} /* #{File.basename(path)} in Sources */ = {isa = PBXBuildFile; fileRef = #{file_ref_ids[path]} /* #{File.basename(path)} */; };"
end
resource_files.each do |path|
  pbx_build_file_lines << "\t\t#{build_file_ids[path]} /* #{File.basename(path)} in Resources */ = {isa = PBXBuildFile; fileRef = #{file_ref_ids[path]} /* #{File.basename(path)} */; };"
end

pbx_file_reference_lines = []
pbx_file_reference_lines << "\t\t#{product_ref} /* #{APP_PRODUCT_NAME}.app */ = {isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = #{quote("#{APP_PRODUCT_NAME}.app")}; sourceTree = BUILT_PRODUCTS_DIR; };"

(app_files + model_files + service_files + view_files + resource_files + support_files).each do |path|
  basename = File.basename(path)
  group_relative = path
  source_tree = "SOURCE_ROOT"

  if path.start_with?("Sources/AstronomyObservationPlanningApp.swift")
    group_relative = basename
    source_tree = "\"<group>\""
  elsif path.start_with?("Sources/Models/")
    group_relative = basename
    source_tree = "\"<group>\""
  elsif path.start_with?("Sources/Services/")
    group_relative = basename
    source_tree = "\"<group>\""
  elsif path.start_with?("Sources/Views/")
    group_relative = basename
    source_tree = "\"<group>\""
  elsif path.start_with?("Sources/Resources/")
    group_relative = basename
    source_tree = "\"<group>\""
  end

  pbx_file_reference_lines << "\t\t#{file_ref_ids[path]} /* #{basename} */ = {isa = PBXFileReference; lastKnownFileType = #{file_type(path)}; path = #{quote(group_relative)}; sourceTree = #{source_tree}; };"
end

sources_children = [
  file_ref_ids[app_files.first],
  groups[:models],
  groups[:services],
  groups[:views],
  groups[:resources]
]

models_children = model_files.map { |path| file_ref_ids[path] }
services_children = service_files.map { |path| file_ref_ids[path] }
views_children = view_files.map { |path| file_ref_ids[path] }
resources_children = resource_files.map { |path| file_ref_ids[path] }
support_children = support_files.map { |path| file_ref_ids[path] }

pbx_group_lines = []
pbx_group_lines << "\t\t#{groups[:main]} = {isa = PBXGroup; children = ("
pbx_group_lines << "\t\t\t#{groups[:sources]} /* Sources */, "
pbx_group_lines << "\t\t\t#{groups[:support]} /* Support */, "
pbx_group_lines << "\t\t\t#{groups[:products]} /* Products */, "
pbx_group_lines << "\t\t); sourceTree = \"<group>\"; };"
pbx_group_lines << "\t\t#{groups[:products]} /* Products */ = {isa = PBXGroup; children = ("
pbx_group_lines << "\t\t\t#{product_ref} /* #{APP_PRODUCT_NAME}.app */, "
pbx_group_lines << "\t\t); name = Products; sourceTree = \"<group>\"; };"
pbx_group_lines << "\t\t#{groups[:sources]} /* Sources */ = {isa = PBXGroup; children = ("
sources_children.each do |child_id|
  comment =
    case child_id
    when groups[:models] then "Models"
    when groups[:services] then "Services"
    when groups[:views] then "Views"
    when groups[:resources] then "Resources"
    else File.basename(app_files.first)
    end
  pbx_group_lines << "\t\t\t#{child_id} /* #{comment} */, "
end
pbx_group_lines << "\t\t); path = Sources; sourceTree = SOURCE_ROOT; };"
pbx_group_lines << "\t\t#{groups[:models]} /* Models */ = {isa = PBXGroup; children = ("
models_children.each { |id| pbx_group_lines << "\t\t\t#{id} /* #{File.basename(model_files.find { |path| file_ref_ids[path] == id })} */, " }
pbx_group_lines << "\t\t); path = Models; sourceTree = \"<group>\"; };"
pbx_group_lines << "\t\t#{groups[:services]} /* Services */ = {isa = PBXGroup; children = ("
services_children.each { |id| pbx_group_lines << "\t\t\t#{id} /* #{File.basename(service_files.find { |path| file_ref_ids[path] == id })} */, " }
pbx_group_lines << "\t\t); path = Services; sourceTree = \"<group>\"; };"
pbx_group_lines << "\t\t#{groups[:views]} /* Views */ = {isa = PBXGroup; children = ("
views_children.each { |id| pbx_group_lines << "\t\t\t#{id} /* #{File.basename(view_files.find { |path| file_ref_ids[path] == id })} */, " }
pbx_group_lines << "\t\t); path = Views; sourceTree = \"<group>\"; };"
pbx_group_lines << "\t\t#{groups[:resources]} /* Resources */ = {isa = PBXGroup; children = ("
resources_children.each { |id| pbx_group_lines << "\t\t\t#{id} /* #{File.basename(resource_files.find { |path| file_ref_ids[path] == id })} */, " }
pbx_group_lines << "\t\t); path = Resources; sourceTree = \"<group>\"; };"
pbx_group_lines << "\t\t#{groups[:support]} /* Support */ = {isa = PBXGroup; children = ("
support_children.each { |id| pbx_group_lines << "\t\t\t#{id} /* #{File.basename(support_files.find { |path| file_ref_ids[path] == id })} */, " }
pbx_group_lines << "\t\t); name = Support; sourceTree = \"<group>\"; };"

pbx_sources_files = all_source_files.map do |path|
  "\t\t\t#{build_file_ids[path]} /* #{File.basename(path)} in Sources */, "
end

pbx_resources_files = resource_files.map do |path|
  "\t\t\t#{build_file_ids[path]} /* #{File.basename(path)} in Resources */, "
end

pbxproj = <<~PBXPROJ
// !$*UTF8*$!
{
\tarchiveVersion = 1;
\tclasses = {
\t};
\tobjectVersion = 56;
\tobjects = {

/* Begin PBXBuildFile section */
#{pbx_build_file_lines.join("\n")}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
#{pbx_file_reference_lines.join("\n")}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
\t\t#{frameworks_phase_id} /* Frameworks */ = {
\t\t\tisa = PBXFrameworksBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
#{pbx_group_lines.join("\n")}
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
\t\t#{target_id} /* #{PROJECT_NAME} */ = {
\t\t\tisa = PBXNativeTarget;
\t\t\tbuildConfigurationList = #{target_config_list_id} /* Build configuration list for PBXNativeTarget "#{PROJECT_NAME}" */;
\t\t\tbuildPhases = (
\t\t\t\t#{sources_phase_id} /* Sources */,
\t\t\t\t#{frameworks_phase_id} /* Frameworks */,
\t\t\t\t#{resources_phase_id} /* Resources */,
\t\t\t);
\t\t\tbuildRules = (
\t\t\t);
\t\t\tdependencies = (
\t\t\t);
\t\t\tname = #{PROJECT_NAME};
\t\t\tproductName = #{quote(APP_PRODUCT_NAME)};
\t\t\tproductReference = #{product_ref} /* #{APP_PRODUCT_NAME}.app */;
\t\t\tproductType = "com.apple.product-type.application";
\t\t};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
\t\t#{project_id} /* Project object */ = {
\t\t\tisa = PBXProject;
\t\t\tattributes = {
\t\t\t\tBuildIndependentTargetsInParallel = 1;
\t\t\t\tLastSwiftUpdateCheck = 1630;
\t\t\t\tLastUpgradeCheck = 1630;
\t\t\t\tTargetAttributes = {
\t\t\t\t\t#{target_id} = {
\t\t\t\t\t\tCreatedOnToolsVersion = 16.3;
\t\t\t\t\t\tProvisioningStyle = Automatic;
\t\t\t\t\t};
\t\t\t\t};
\t\t\t};
\t\t\tbuildConfigurationList = #{project_config_list_id} /* Build configuration list for PBXProject "#{PROJECT_NAME}" */;
\t\t\tcompatibilityVersion = "Xcode 16.0";
\t\t\tdevelopmentRegion = en;
\t\t\thasScannedForEncodings = 0;
\t\t\tknownRegions = (
\t\t\t\ten,
\t\t\t\tBase,
\t\t\t);
\t\t\tmainGroup = #{groups[:main]};
\t\t\tproductRefGroup = #{groups[:products]} /* Products */;
\t\t\tprojectDirPath = "";
\t\t\tprojectRoot = "";
\t\t\ttargets = (
\t\t\t\t#{target_id} /* #{PROJECT_NAME} */,
\t\t\t);
\t\t};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
\t\t#{resources_phase_id} /* Resources */ = {
\t\t\tisa = PBXResourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
#{pbx_resources_files.join("\n")}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
\t\t#{sources_phase_id} /* Sources */ = {
\t\t\tisa = PBXSourcesBuildPhase;
\t\t\tbuildActionMask = 2147483647;
\t\t\tfiles = (
#{pbx_sources_files.join("\n")}
\t\t\t);
\t\t\trunOnlyForDeploymentPostprocessing = 0;
\t\t};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
\t\t#{project_debug_config_id} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t#{project_release_config_id} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tCLANG_ENABLE_MODULES = YES;
\t\t\t\tENABLE_USER_SCRIPT_SANDBOXING = YES;
\t\t\t\tSDKROOT = macosx;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t};
\t\t\tname = Release;
\t\t};
\t\t#{target_debug_config_id} /* Debug */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tARCHS = "$(ARCHS_STANDARD)";
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = AstronomyObservationPlanning.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Smart Scope Observation Planner";
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.education";
\t\t\t\tINFOPLIST_KEY_NSLocationUsageDescription = "Smart Scope uses your current location to create observing sites with GPS coordinates and altitude.";
\t\t\t\tINFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Smart Scope uses your current location to create observing sites with GPS coordinates and altitude.";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "Copyright BigSkyAstro Richard Derry";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tONLY_ACTIVE_ARCH = NO;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = #{APP_BUNDLE_ID};
\t\t\t\tPRODUCT_NAME = #{quote(APP_PRODUCT_NAME)};
\t\t\t\tSUPPORTED_PLATFORMS = macosx;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t};
\t\t\tname = Debug;
\t\t};
\t\t#{target_release_config_id} /* Release */ = {
\t\t\tisa = XCBuildConfiguration;
\t\t\tbuildSettings = {
\t\t\t\tARCHS = "$(ARCHS_STANDARD)";
\t\t\t\tASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
\t\t\t\tCODE_SIGN_ENTITLEMENTS = AstronomyObservationPlanning.entitlements;
\t\t\t\tCODE_SIGN_STYLE = Automatic;
\t\t\t\tCURRENT_PROJECT_VERSION = 1;
\t\t\t\tENABLE_HARDENED_RUNTIME = YES;
\t\t\t\tGENERATE_INFOPLIST_FILE = YES;
\t\t\t\tINFOPLIST_KEY_CFBundleDisplayName = "Smart Scope Observation Planner";
\t\t\t\tINFOPLIST_KEY_LSApplicationCategoryType = "public.app-category.education";
\t\t\t\tINFOPLIST_KEY_NSLocationUsageDescription = "Smart Scope uses your current location to create observing sites with GPS coordinates and altitude.";
\t\t\t\tINFOPLIST_KEY_NSLocationWhenInUseUsageDescription = "Smart Scope uses your current location to create observing sites with GPS coordinates and altitude.";
\t\t\t\tINFOPLIST_KEY_NSHumanReadableCopyright = "Copyright BigSkyAstro Richard Derry";
\t\t\t\tLD_RUNPATH_SEARCH_PATHS = (
\t\t\t\t\t"$(inherited)",
\t\t\t\t\t"@executable_path/../Frameworks",
\t\t\t\t);
\t\t\t\tMACOSX_DEPLOYMENT_TARGET = 15.0;
\t\t\t\tMARKETING_VERSION = 1.0;
\t\t\t\tONLY_ACTIVE_ARCH = NO;
\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = #{APP_BUNDLE_ID};
\t\t\t\tPRODUCT_NAME = #{quote(APP_PRODUCT_NAME)};
\t\t\t\tSUPPORTED_PLATFORMS = macosx;
\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;
\t\t\t\tSWIFT_VERSION = 6.0;
\t\t\t};
\t\t\tname = Release;
\t\t};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
\t\t#{project_config_list_id} /* Build configuration list for PBXProject "#{PROJECT_NAME}" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t#{project_debug_config_id} /* Debug */,
\t\t\t\t#{project_release_config_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
\t\t#{target_config_list_id} /* Build configuration list for PBXNativeTarget "#{PROJECT_NAME}" */ = {
\t\t\tisa = XCConfigurationList;
\t\t\tbuildConfigurations = (
\t\t\t\t#{target_debug_config_id} /* Debug */,
\t\t\t\t#{target_release_config_id} /* Release */,
\t\t\t);
\t\t\tdefaultConfigurationIsVisible = 0;
\t\t\tdefaultConfigurationName = Release;
\t\t};
/* End XCConfigurationList section */
\t};
\trootObject = #{project_id} /* Project object */;
}
PBXPROJ

workspace = <<~XML
<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
XML

scheme = <<~XML
<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1630"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "#{target_id}"
               BuildableName = "#{APP_PRODUCT_NAME}.app"
               BlueprintName = "#{PROJECT_NAME}"
               ReferencedContainer = "container:#{PROJECT_NAME}.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES">
      <Testables>
      </Testables>
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "#{target_id}"
            BuildableName = "#{APP_PRODUCT_NAME}.app"
            BlueprintName = "#{PROJECT_NAME}"
            ReferencedContainer = "container:#{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "#{target_id}"
            BuildableName = "#{APP_PRODUCT_NAME}.app"
            BlueprintName = "#{PROJECT_NAME}"
            ReferencedContainer = "container:#{PROJECT_NAME}.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
XML

FileUtils.mkdir_p(File.dirname(PBXPROJ_PATH))
FileUtils.mkdir_p(File.dirname(WORKSPACE_PATH))
FileUtils.mkdir_p(File.dirname(SCHEME_PATH))

File.write(PBXPROJ_PATH, pbxproj)
File.write(WORKSPACE_PATH, workspace)
File.write(SCHEME_PATH, scheme)

puts "Generated #{PBXPROJ_PATH}"
puts "Generated #{WORKSPACE_PATH}"
puts "Generated #{SCHEME_PATH}"

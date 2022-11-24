#!/usr/bin/env ruby

require 'xcodeproj'

project_name = ARGV[0]

unless project_name
    puts "ERROR: Missing argument"
    exit 1
end

proj_path = "#{project_name}.xcodeproj"
workspace_path = "#{project_name}.xcworkspace"

# rename project file
system("git mv GoNativeIOS.xcodeproj #{proj_path}")

# rename target
proj = Xcodeproj::Project.open(proj_path)
proj.targets.first.name = project_name
proj.save

# recreate scheme
schemes_dir = Xcodeproj::XCScheme.shared_data_dir(proj_path)
FileUtils.rm_rf(schemes_dir)
FileUtils.mkdir_p(schemes_dir)

scheme = Xcodeproj::XCScheme.new
target = proj.targets.first

test_target = target if target.respond_to?(:test_target_type?) && target.test_target_type?
launch_target = target.respond_to?(:launchable_target_type?) && target.launchable_target_type?
scheme.configure_with_targets(target, test_target, :launch_target => launch_target)

scheme.save_as(proj_path, target.name, true)

# fix workspace references
FileUtils.rm_rf("GoNativeIOS.xcworkspace")
proj_ref = Xcodeproj::Workspace::FileReference.new(proj_path)
pods_ref = Xcodeproj::Workspace::FileReference.new("Pods/Pods.xcodeproj")
workspace = Xcodeproj::Workspace.new(nil, proj_ref, pods_ref)
workspace.save_as(workspace_path)

system('pod install')

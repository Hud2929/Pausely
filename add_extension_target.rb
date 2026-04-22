#!/usr/bin/env ruby
# Adds DeviceActivityMonitor extension target to Xcode project

require 'xcodeproj'

project_path = 'Pausely.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Check if target already exists
target_name = 'DeviceActivityMonitor'
if project.targets.any? { |t| t.name == target_name }
  puts "Target '#{target_name}' already exists!"
  exit 0
end

puts "Adding #{target_name} extension target..."

# Find the main app target
main_target = project.targets.find { |t| t.name == 'Pausely' }
unless main_target
  puts "Error: Could not find main 'Pausely' target!"
  exit 1
end

# Create the extension target
extension_target = project.new_target(
  :app_extension,
  target_name,
  :ios,
  '16.0',
  nil,
  nil
)

# Set product type to device activity extension
extension_target.product_type = 'com.apple.product-type.device-activity-monitor'

# Add source files to the target
source_files = [
  'DeviceActivityMonitor/DeviceActivityMonitor.swift'
]

source_files.each do |file_path|
  if File.exist?(file_path)
    file_ref = project.main_group.find_file_by_path(file_path) || project.main_group.new_file(file_path)
    extension_target.add_file_references([file_ref])
    puts "Added #{file_path} to target"
  else
    puts "Warning: #{file_path} not found"
  end
end

# Add required frameworks
frameworks_group = project.groups.find { |g| g.name == 'Frameworks' } || project.main_group.new_group('Frameworks')

['DeviceActivity', 'FamilyControls', 'ManagedSettings'].each do |framework|
  framework_ref = frameworks_group.new_reference("System/Library/Frameworks/#{framework}.framework")
  framework_ref.last_known_file_type = 'wrapper.framework'
  framework_ref.source_tree = 'SDKROOT'
  extension_target.frameworks_build_phase.add_file_reference(framework_ref)
end

# Set entitlements file
extension_target.build_configurations.each do |config|
  config.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'DeviceActivityMonitor/DeviceActivityMonitor.entitlements'
  config.build_settings['PRODUCT_BUNDLE_IDENTIFIER'] = 'com.pausely.app.DeviceActivityMonitor'
  config.build_settings['SWIFT_VERSION'] = '5.0'
  config.build_settings['TARGETED_DEVICE_FAMILY'] = '1,2'
end

# Add embed app extension build phase to main target
embed_phase = main_target.new_copy_files_build_phase('Embed Foundation Extensions')
embed_phase.dst_subfolder_spec = '13' # PlugIns folder
embed_phase.add_file_reference(extension_target.product_reference)

# Save project
project.save
puts "✅ Successfully added #{target_name} target!"
puts ""
puts "IMPORTANT: You still need to:"
puts "1. Add DeviceActivityReport target (similar process)"
puts "2. Regenerate provisioning profiles in Apple Developer Portal"
puts "3. Build and test on a real device (simulator has limited Screen Time support)"

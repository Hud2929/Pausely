#!/usr/bin/env ruby
# Fixes DeviceActivity extension targets - they can only build for device, not simulator

require 'xcodeproj'

project_path = 'Pausely.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Fix DeviceActivityMonitor
monitor_target = project.targets.find { |t| t.name == 'DeviceActivityMonitor' }
if monitor_target
  # Remove from embed phase of main target
  main_target = project.targets.find { |t| t.name == 'Pausely' }
  embed_phase = main_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
  if embed_phase
    # Find and remove the reference
    file_ref = embed_phase.files_references.find { |r| r.display_name == 'DeviceActivityMonitor.appex' }
    embed_phase.remove_file_reference(file_ref) if file_ref
  end
  
  # Update build settings for device only
  monitor_target.build_configurations.each do |config|
    config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos'
    config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
  end
  
  puts "✅ Fixed DeviceActivityMonitor for device-only build"
end

# Fix DeviceActivityReport
report_target = project.targets.find { |t| t.name == 'DeviceActivityReport' }
if report_target
  # Remove from embed phase of main target
  main_target = project.targets.find { |t| t.name == 'Pausely' }
  embed_phase = main_target.copy_files_build_phases.find { |p| p.name == 'Embed Foundation Extensions' }
  if embed_phase
    file_ref = embed_phase.files_references.find { |r| r.display_name == 'DeviceActivityReport.appex' }
    embed_phase.remove_file_reference(file_ref) if file_ref
  end
  
  # Update build settings for device only
  report_target.build_configurations.each do |config|
    config.build_settings['SUPPORTED_PLATFORMS'] = 'iphoneos'
    config.build_settings['SUPPORTS_MACCATALYST'] = 'NO'
  end
  
  puts "✅ Fixed DeviceActivityReport for device-only build"
end

project.save
puts ""
puts "⚠️  IMPORTANT: DeviceActivity extensions can only run on physical devices!"
puts "   The main app will build for simulator, but Screen Time features require:"
puts "   1. Build and run on a physical iPhone"
puts "   2. Apple-approved Family Controls entitlement"
puts "   3. Proper provisioning profiles"

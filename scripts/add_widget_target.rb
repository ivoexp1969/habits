#!/usr/bin/env ruby
# Adds the HabitWidget WidgetKit extension target to Runner.xcodeproj,
# wires App Group entitlements on Runner + HabitWidget, embeds the appex.
# Idempotent: re-running removes an existing HabitWidget target first.
require 'xcodeproj'

PROJECT   = 'ios/Runner.xcodeproj'
TEAM      = 'YP2QH7PM93'
APP_GROUP = 'group.com.ivoexp.habits'
WIDGET    = 'HabitWidget'
WIDGET_BID = 'com.ivoexp.habits.HabitWidget'
DIST_IDENT = 'iPhone Distribution: Ivaylo Mihaylov (YP2QH7PM93)'
WIDGET_PROFILE = 'Habits Widget App Store'

proj = Xcodeproj::Project.open(PROJECT)
runner = proj.targets.find { |t| t.name == 'Runner' }
raise 'Runner target not found' unless runner

# --- clean any previous widget target/group (idempotent) ---
proj.targets.select { |t| t.name == WIDGET }.each(&:remove_from_project)
if (g = proj.main_group[WIDGET]); g.remove_from_project; end
# remove stale embed build files referencing a widget appex
runner.copy_files_build_phases.each do |ph|
  ph.files.dup.each do |bf|
    disp = bf.display_name.to_s
    ph.remove_build_file(bf) if disp.include?('HabitWidget')
  end
end

# --- create the app-extension target ---
widget = proj.new_target(:app_extension, WIDGET, :ios, '14.0')

# group + file references (files live in ios/HabitWidget/)
group = proj.main_group.new_group(WIDGET, WIDGET)
swift_ref = group.new_reference('HabitWidget.swift')
plist_ref = group.new_reference('Info.plist')
ent_ref   = group.new_reference('HabitWidget.entitlements')

widget.source_build_phase.add_file_reference(swift_ref)

# --- build settings on every config of the widget target ---
widget.build_configurations.each do |c|
  s = c.build_settings
  s['PRODUCT_BUNDLE_IDENTIFIER']     = WIDGET_BID
  s['PRODUCT_NAME']                  = '$(TARGET_NAME)'
  s['INFOPLIST_FILE']                = 'HabitWidget/Info.plist'
  s['GENERATE_INFOPLIST_FILE']       = 'NO'
  s['IPHONEOS_DEPLOYMENT_TARGET']    = '14.0'
  s['SWIFT_VERSION']                 = '5.0'
  s['TARGETED_DEVICE_FAMILY']        = '1,2'
  s['MARKETING_VERSION']             = '1.3.0'
  s['CURRENT_PROJECT_VERSION']       = '9'
  s['SKIP_INSTALL']                  = 'YES'
  s['CODE_SIGN_ENTITLEMENTS']        = 'HabitWidget/HabitWidget.entitlements'
  s['CODE_SIGN_STYLE']               = 'Manual'
  s['DEVELOPMENT_TEAM']              = TEAM
  s['CODE_SIGN_IDENTITY[sdk=iphoneos*]'] = DIST_IDENT
  s['PROVISIONING_PROFILE_SPECIFIER'] = WIDGET_PROFILE
  s['LD_RUNPATH_SEARCH_PATHS']       = ['$(inherited)', '@executable_path/Frameworks', '@executable_path/../../Frameworks']
  s['ASSETCATALOG_COMPILER_GENERATE_ASSET_SYMBOLS'] = 'NO'
end

# --- embed the appex into Runner (Embed App Extensions, PlugIns dir) ---
embed = runner.copy_files_build_phases.find { |p| p.symbol_dst_subfolder_spec == :plug_ins && p.name == 'Embed App Extensions' }
embed ||= runner.new_copy_files_build_phase('Embed App Extensions')
embed.symbol_dst_subfolder_spec = :plug_ins
bf = embed.add_file_reference(widget.product_reference)
bf.settings = { 'ATTRIBUTES' => ['RemoveHeadersOnCopy'] }

# --- Runner depends on widget so it builds first ---
runner.add_dependency(widget)

# --- App Group entitlement on Runner ---
ent_path = 'ios/Runner/Runner.entitlements'
unless File.exist?(ent_path)
  File.write(ent_path, <<~XML)
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
    \t<key>com.apple.security.application-groups</key>
    \t<array>
    \t\t<string>#{APP_GROUP}</string>
    \t</array>
    </dict>
    </plist>
  XML
end
# reference Runner.entitlements in the Runner group if not present
runner_group = proj.main_group['Runner']
unless runner_group.files.any? { |f| f.display_name == 'Runner.entitlements' }
  runner_group.new_reference('Runner.entitlements')
end
runner.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
end

proj.save
puts "OK: added #{WIDGET} target (#{WIDGET_BID}), embedded in Runner, App Group #{APP_GROUP} on both."
puts "Targets now: #{proj.targets.map(&:name).join(', ')}"

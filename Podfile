# Uncomment this line to define a global platform for your project
platform :ios, '8.0'

target 'BLEDeviceSimulator' do
  # Comment this line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for BLEDeviceSimulator

  pod 'CocoaLumberjack/Swift'
  pod 'LumberjackConsole', '~> 2.4'

  target 'BLEDeviceSimulatorTests' do
    inherit! :search_paths
    # Pods for testing
  end

end

target 'KMBLENavigationKit' do
  # Comment this line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for KMBLENavigationKit
  pod 'CocoaLumberjack/Swift'
end

target 'KomootAppSimulator' do
  # Comment this line if you're not using Swift and don't want to use dynamic frameworks
  use_frameworks!

  # Pods for KomootAppSimulator
  pod 'CocoaLumberjack/Swift'
  pod 'LumberjackConsole', '~> 2.4'
  
  target 'KomootAppSimulatorTests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
    installer.pods_project.build_configurations.each do |config|
        # Configure Pod targets for Xcode 8 compatibility
        config.build_settings['SWIFT_VERSION'] = '2.3'
        config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = 'M999CM95TV/'
        config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
    end
end

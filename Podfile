platform :ios, '9.0'

target 'BLEDeviceSimulator' do
  use_frameworks!

  pod 'CocoaLumberjack/Swift', '3.4.2'
  pod 'LumberjackConsole', '3.3.0'  #https://github.com/PTEz/LumberjackConsole

  target 'BLEDeviceSimulatorTests' do
    inherit! :search_paths
  end
end

target 'KomootAppSimulator' do
  use_frameworks!

  pod 'CocoaLumberjack/Swift', '3.4.2'

  target 'KomootAppSimulatorTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
    installer.pods_project.build_configurations.each do |config|
        config.build_settings['ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES'] = 'NO'
    end
end

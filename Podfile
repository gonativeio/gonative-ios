# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

source 'https://cdn.cocoapods.org/'
source 'git@github.com:gonativeio/gonative-specs.git'

require_relative './plugins.rb'

target default_app_target do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for GonativeIO
  pod 'GoNativeCore'
  pod 'GonativeIcons'
  
  use_plugins!

  target 'GoNativeIOSTests' do
    inherit! :search_paths
    # Pods for testing
  end

end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      config.build_settings.delete 'ARCHS'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end
  installer.pods_project.build_configurations.each do |config|
    config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
  end
end

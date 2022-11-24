# frozen_string_literal: true

require 'cocoapods'
require 'xcodeproj'
require 'active_support/inflector'

def use_plugins!
  app_config = JSON.parse(File.read(__dir__ + '/LeanIOS/appConfig.json'))
  services = app_config['services']

  services = services.select do |_service_name, service| 
    next unless service
    service['active'] && service['iosPluginName'] 
  end

  services.each do |service_name, service|
    pod_name = service['iosPluginName']
    variant = service['plugin']&.camelize || 'Binary'

    pod "#{pod_name}/#{variant}"
  end
end

def default_app_target
  proj_path = Dir.glob("*.xcodeproj").first
  proj = Xcodeproj::Project.open(proj_path)

  proj.targets.first.name
end

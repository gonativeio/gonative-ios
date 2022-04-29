# frozen_string_literal: true

require 'cocoapods'
require 'active_support/inflector'

def use_plugins!
  app_config = JSON.parse(File.read(__dir__ + '/LeanIOS/appConfig.json'))
  services = app_config['services']

  services = services.select { |_service_name, service| service['active'] && service['iosPluginName'] }

  services.each do |service_name, service|
    pod_name = service['iosPluginName']
    variant = service['plugin']&.camelize || 'Binary'

    pod "#{pod_name}/#{variant}"
  end
end

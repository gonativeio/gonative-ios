# frozen_string_literal: true

require 'cocoapods'
require 'active_support/inflector'

def use_plugins!
  app_config = JSON.parse(File.read('LeanIOS/appConfig.json'))
  services = app_config['services']

  services = services.select { |_service_name, service| %w[source binary].include? service['plugin'] }

  services.each do |service_name, service|
    pod_name = "#{service_name.camelize}Plugin"
    variant = service['plugin'].camelize

    pod "#{pod_name}/#{variant}"
  end
end

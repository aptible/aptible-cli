$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

Bundler.require :development

require 'simplecov'
SimpleCov.start

if ENV['CI']
  require 'codecov'
  SimpleCov.formatter = SimpleCov::Formatter::Codecov
end

# Load shared spec files
Dir["#{File.dirname(__FILE__)}/shared/**/*.rb"].each do |file|
  require file
end

# Require library up front
require 'aptible/cli'

RSpec.configure do |config|
  config.before {}
end

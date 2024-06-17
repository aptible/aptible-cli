# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'English'
require 'aptible/cli/version'

Gem::Specification.new do |spec|
  spec.name          = 'aptible-cli'
  spec.version       = Aptible::CLI::VERSION
  spec.authors       = ['Frank Macreery']
  spec.email         = ['frank@macreery.com']
  spec.description   = 'Aptible CLI'
  spec.summary       = 'Command-line interface for Aptible services'
  spec.homepage      = 'https://github.com/aptible/aptible-cli'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($RS)
  spec.executables   = spec.files.grep(%r{bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{spec/})
  spec.require_paths = ['lib']

  spec.add_dependency 'aptible-resource', '~> 1.1'
  spec.add_dependency 'aptible-api', '~> 1.5.3'
  spec.add_dependency 'aptible-auth', '~> 1.2.4'
  spec.add_dependency 'aptible-billing', '~> 1.0'
  spec.add_dependency 'thor', '~> 0.20.0'
  spec.add_dependency 'git', '< 2.2'
  spec.add_dependency 'term-ansicolor'
  spec.add_dependency 'chronic_duration', '~> 0.10.6'
  spec.add_dependency 'cbor'
  spec.add_dependency 'aws-sdk', '~> 2.0'
  spec.add_dependency 'bigdecimal', '~> 1.3.5' # https://github.com/ruby/bigdecimal#which-version-should-you-select

  # Temporarily pin ffi until https://github.com/ffi/ffi/issues/868 is fixed
  spec.add_dependency 'ffi', '<= 1.14.1' if Gem.win_platform?
  spec.add_dependency 'win32-process' if Gem.win_platform?

  spec.add_dependency 'activesupport', '>= 4.0', '< 6.0'
  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'aptible-tasks', '~> 0.5.8'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 3.2'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'climate_control', '= 0.0.3'
  spec.add_development_dependency 'fabrication', '~> 2.15.2'
end

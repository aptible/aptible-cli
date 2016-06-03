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

  spec.add_dependency 'aptible-api', '~> 0.9.7'
  spec.add_dependency 'aptible-auth', '~> 0.11.8'
  spec.add_dependency 'aptible-resource', '~> 0.3.6'
  spec.add_dependency 'thor', '~> 0.19.1'
  spec.add_dependency 'git'
  spec.add_dependency 'term-ansicolor'
  spec.add_dependency 'chronic_duration', '~> 0.10.6'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'aptible-tasks', '>= 0.2.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 2.0'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'climate_control'
  spec.add_development_dependency 'fabrication', '~> 2.15.2'
end

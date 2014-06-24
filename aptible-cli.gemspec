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
  spec.description   = %q(Aptible CLI)
  spec.summary       = %q(Command-line interface for Aptible services)
  spec.homepage      = 'https://github.com/aptible/aptible-cli'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($RS)
  spec.executables   = spec.files.grep(/^bin\//) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(/^spec\//)
  spec.require_paths = ['lib']

  spec.add_dependency 'i18n', '0.6.9'
  spec.add_dependency 'json', '1.8.1'
  spec.add_dependency 'minitest', '5.3.5'
  spec.add_dependency 'thread_safe', '0.3.4'
  spec.add_dependency 'tzinfo', '1.2.1'
  spec.add_dependency 'activesupport', '4.1.1'
  spec.add_dependency 'multipart-post', '2.0.0'
  spec.add_dependency 'faraday', '0.9.0'
  spec.add_dependency 'gem_config', '0.3.1'
  spec.add_dependency 'multi_json', '1.10.1'
  spec.add_dependency 'jwt', '0.1.13'
  spec.add_dependency 'fridge', '0.2.2'
  spec.add_dependency 'uri_template', '0.7.0'
  spec.add_dependency 'aptible-resource', '0.2.3'
  spec.add_dependency 'multi_xml', '0.5.5'
  spec.add_dependency 'rack', '1.5.2'
  spec.add_dependency 'oauth2-aptible', '0.9.4'
  spec.add_dependency 'mime-types', '1.25.1'
  spec.add_dependency 'rest-client', '1.6.7'
  spec.add_dependency 'stripe', '1.14.0'
  spec.add_dependency 'aptible-auth', '0.5.8'
  spec.add_dependency 'aptible-api', '0.5.6'
  spec.add_dependency 'git', '1.2.7'
  spec.add_dependency 'thor', '0.19.1'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'aptible-tasks', '>= 0.2.0'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '~> 2.0'
  spec.add_development_dependency 'pry'
end

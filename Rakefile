require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.pattern = 'spec/**/*_spec.rb'
  spec.rspec_opts = '--exclude-pattern spec/integration/**/*_spec.rb'
end

RuboCop::RakeTask.new

task default: [:spec, :rubocop]

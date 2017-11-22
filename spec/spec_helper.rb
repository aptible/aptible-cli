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

class SpecRenderer < Aptible::CLI::Renderer::Base
  def initialize
    @nodes = []
  end

  def render(node)
    # For now, we don't support rendering twice, and we probably never need to.
    raise 'Rendered twice!' unless @nodes.empty?
    @nodes << node
    nil
  end

  def text
    Aptible::CLI::Renderer::Text.new.render(@nodes.first)
  end

  def json
    JSON.parse(Aptible::CLI::Renderer::Json.new.render(@nodes.first))
  end

  def text?
    true
  end

  def json?
    true
  end
end

module SpecHarness
  def reset_spec_harness
    @stream = StringIO.new
    @renderer = SpecRenderer.new

    logger = Logger.new(@stream)

    allow(Aptible::CLI).to receive(:logger).and_return(logger)
    allow(Aptible::CLI::Renderer).to receive(:current).and_return(@renderer)
  end

  def captured_output_text
    @renderer.text
  end

  def captured_output_json
    @renderer.json
  end

  def captured_logs
    pos = @stream.pos

    begin
      @stream.rewind
      @stream.read
    ensure
      @stream.pos = pos
    end
  end
end

RSpec.configure do |config|
  config.before(:each) { reset_spec_harness }

  config.include(SpecHarness)

  # We make the CLI believe it's running in a toolbelt context to avoid running
  # the toolbelt nag every time it initializes.
  config.around(:each) do |example|
    ClimateControl.modify(APTIBLE_TOOLBELT: '1') { example.run }
  end
end

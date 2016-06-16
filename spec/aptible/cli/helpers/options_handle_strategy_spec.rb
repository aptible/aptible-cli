require 'spec_helper'

describe Aptible::CLI::Helpers::App::OptionsHandleStrategy do
  it 'is usable when app is set' do
    s = described_class.new(app: 'foo')
    expect(s.usable?).to be_truthy
  end

  it 'passes options through' do
    s = described_class.new(app: 'foo', environment: 'bar')
    expect(s.app_handle).to eq('foo')
    expect(s.env_handle).to eq('bar')
  end
end

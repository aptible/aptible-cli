require 'ostruct'
require 'spec_helper'

class App < OpenStruct
end

class Service < OpenStruct
end

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }

  let(:service) { Service.new(process_type: 'web') }
  let(:app) do
    App.new(handle: 'foobar', status: 'provisioned', services: [service])
  end

  describe '#logs' do
    it 'should fail if the app is unprovisioned' do
      allow(app).to receive(:status) { 'pending' }
      allow(subject).to receive(:ensure_app) { app }
      expect { subject.send('logs') }.to raise_error(Thor::Error)
    end

    it 'should fail if the app has no services' do
      allow(app).to receive(:services) { [] }
      allow(subject).to receive(:ensure_app) { app }
      expect { subject.send('logs') }.to raise_error(Thor::Error)
    end
  end
end

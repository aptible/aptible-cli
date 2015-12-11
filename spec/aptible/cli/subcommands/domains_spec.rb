require 'ostruct'
require 'spec_helper'

class App < OpenStruct
end

class Service < OpenStruct
end

class Operation < OpenStruct
end

class Vhost < OpenStruct
end

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }

  let(:service) { Service.new(process_type: 'web') }
  let(:op) { Operation.new(status: 'succeeded') }
  let(:app) { App.new(handle: 'hello', services: [service]) }
  let(:apps) { [app] }

  let(:vhost1) { Vhost.new(virtual_domain: 'domain1', external_host: 'host1') }
  let(:vhost2) { Vhost.new(virtual_domain: 'domain2', external_host: 'host2') }

  describe '#domains' do
    it 'should print out the hostnames' do
      allow(service).to receive(:create_operation) { op }
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect(app).to receive(:vhosts) { [vhost1, vhost2] }
      expect(subject).to receive(:say).with('domain1')
      expect(subject).to receive(:say).with('domain2')

      subject.send('domains')
    end

    it 'should fail if app is non-existent' do
      allow(service).to receive(:create_operation) { op }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect do
        subject.send('domains')
      end.to raise_error(Thor::Error)
    end
  end

  describe '#domains:hostnames' do
    it 'should print out the hostnames' do
      allow(service).to receive(:create_operation) { op }
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect(app).to receive(:vhosts) { [vhost1, vhost2] }
      expect(subject).to receive(:say).with('domain1 -> host1')
      expect(subject).to receive(:say).with('domain2 -> host2')

      subject.send('domains:hostnames')
    end

    it 'should fail if app is non-existent' do
      allow(service).to receive(:create_operation) { op }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect do
        subject.send('domains:hostnames')
      end.to raise_error(Thor::Error)
    end
  end
end

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
  let(:account) do
    Account.new(bastion_host: 'localhost',
                dumptruck_port: 1234,
                handle: 'aptible')
  end

  let(:vhost1) { Vhost.new(virtual_domain: 'domain1', external_host: 'host1') }
  let(:vhost2) { Vhost.new(virtual_domain: 'domain2', external_host: 'host2') }

  describe '#domains' do
    it 'should print out the hostnames' do
      allow(service).to receive(:create_operation) { op }
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
      allow(account).to receive(:apps) { apps }

      expect(app).to receive(:vhosts) { [vhost1, vhost2] }
      expect(subject).to receive(:say).with('domain1')
      expect(subject).to receive(:say).with('domain2')

      subject.send('domains')
    end

    it 'should fail if app is non-existent' do
      allow(service).to receive(:create_operation) { op }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
      allow(account).to receive(:apps) { apps }

      expect do
        subject.send('domains')
      end.to raise_error(Thor::Error)
    end

    it 'should print hostnames if -v is passed' do
      allow(service).to receive(:create_operation) { op }
      allow(subject).to receive(:options) { { verbose: true, app: 'hello' } }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
      allow(account).to receive(:apps) { apps }

      expect(app).to receive(:vhosts) { [vhost1, vhost2] }
      expect(subject).to receive(:say).with('domain1 -> host1')
      expect(subject).to receive(:say).with('domain2 -> host2')

      subject.send('domains')
    end
  end
end

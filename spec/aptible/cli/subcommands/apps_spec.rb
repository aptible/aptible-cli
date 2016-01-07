require 'ostruct'
require 'spec_helper'

class App < OpenStruct
end

class Service < OpenStruct
end

class Operation < OpenStruct
end

class Account < OpenStruct
end

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }
  before { subject.stub(:attach_to_operation_logs) }

  let(:service) { Service.new(process_type: 'web') }
  let(:op) { Operation.new(status: 'succeeded') }
  let(:account) { Account.new(bastion_host: 'localhost', dumptruck_port: 1234) }
  let(:apps) do
    [App.new(handle: 'hello', services: [service], account: account)]
  end

  describe '#apps:scale' do
    it 'should pass given correct parameters' do
      allow(service).to receive(:create_operation) { op }
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(op).to receive(:resource) { apps.first }
      allow(Aptible::Api::App).to receive(:all) { apps }

      subject.send('apps:scale', 'web', 3)
    end

    it 'should fail if app is non-existent' do
      allow(service).to receive(:create_operation) { op }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect do
        subject.send('apps:scale', 'web', 3)
      end.to raise_error(Thor::Error)
    end

    it 'should fail if number is not a valid number' do
      allow(service).to receive(:create_operation) { op }
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect do
        subject.send('apps:scale', 'web', 'potato')
      end.to raise_error(ArgumentError)
    end
  end
end

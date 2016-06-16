require 'spec_helper'

describe Aptible::CLI::Agent do
  before { subject.stub(:ask) }
  before { subject.stub(:save_token) }
  before { subject.stub(:fetch_token) { double 'token' } }
  before { subject.stub(:attach_to_operation_logs) }

  let!(:account) { Fabricate(:account) }
  let!(:app) { Fabricate(:app, handle: 'hello', account: account) }
  let!(:service) { Fabricate(:service, app: app) }
  let(:op) { Fabricate(:operation, status: 'succeeded', resource: app) }

  describe '#apps:scale' do
    before do
      allow(Aptible::Api::App).to receive(:all) { [app] }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
    end

    it 'should pass given correct parameters' do
      allow(subject).to receive(:options) do
        { app: 'hello', environment: 'foobar' }
      end
      expect(service).to receive(:create_operation!) { op }
      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return([app])
      subject.send('apps:scale', 'web', 3)
    end

    it 'should pass container size param to operation if given' do
      allow(subject).to receive(:options) do
        { app: 'hello', size: 90210, environment: 'foobar' }
      end
      expect(service).to receive(:create_operation!)
        .with(type: 'scale', container_count: 3, container_size: 90210)
        .and_return(op)
      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return([app])
      subject.send('apps:scale', 'web', 3)
    end

    it 'should fail if environment is non-existent' do
      allow(subject).to receive(:options) do
        { environment: 'foo', app: 'web' }
      end
      allow(Aptible::Api::Account).to receive(:all) { [] }
      allow(service).to receive(:create_operation!) { op }

      expect do
        subject.send('apps:scale', 'web', 3)
      end.to raise_error(Thor::Error)
    end

    it 'should fail if app is non-existent' do
      expect do
        subject.send('apps:scale', 'web', 3)
      end.to raise_error(Thor::Error)
    end

    it 'should fail if number is not a valid number' do
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(service).to receive(:create_operation) { op }

      expect do
        subject.send('apps:scale', 'web', 'potato')
      end.to raise_error(ArgumentError)
    end

    it 'should fail if the service does not exist' do
      allow(subject).to receive(:options) do
        { app: 'hello', environment: 'foobar' }
      end
      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return([app])

      expect do
        subject.send('apps:scale', 'potato', 1)
      end.to raise_error(Thor::Error, /Service.* potato.* does not exist/)
    end

    context 'no service' do
      before { app.services = [] }

      it 'should fail if the app has no services' do
        allow(subject).to receive(:options) do
          { app: 'hello', environment: 'foobar' }
        end
        expect(subject).to receive(:environment_from_handle)
          .with('foobar')
          .and_return(account)
        expect(subject).to receive(:apps_from_handle).and_return([app])

        expect do
          subject.send('apps:scale', 'web', 1)
        end.to raise_error(Thor::Error, /deploy the app first/)
      end
    end
  end
end

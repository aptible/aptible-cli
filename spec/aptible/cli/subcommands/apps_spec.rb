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
  let(:account) do
    Account.new(bastion_host: 'localhost',
                dumptruck_port: 1234,
                handle: 'aptible')
  end
  let(:services) { [service] }
  let(:apps) do
    [App.new(handle: 'hello', services: services, account: account)]
  end

  describe '#apps:scale' do
    it 'should pass given correct parameters' do
      allow(service).to receive(:create_operation) { op }
      allow(subject).to receive(:options) do
        { app: 'hello', environment: 'foobar' }
      end
      allow(op).to receive(:resource) { apps.first }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return(apps)
      subject.send('apps:scale', 'web', 3)
    end

    it 'should pass container size param to operation if given' do
      expect(service).to receive(:create_operation)
        .with(type: 'scale', container_count: 3, container_size: 90210)
        .and_return(op)
      allow(subject).to receive(:options) do
        { app: 'hello', size: 90210, environment: 'foobar' }
      end

      allow(op).to receive(:resource) { apps.first }
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return(apps)
      subject.send('apps:scale', 'web', 3)
    end

    it 'should fail if environment is non-existent' do
      allow(subject).to receive(:options) do
        { environment: 'foo', app: 'web' }
      end
      allow(service).to receive(:create_operation) { op }
      allow(Aptible::Api::Account).to receive(:all) { [] }
      allow(account).to receive(:apps) { [apps] }

      expect do
        subject.send('apps:scale', 'web', 3)
      end.to raise_error(Thor::Error)
    end

    it 'should fail if app is non-existent' do
      allow(service).to receive(:create_operation) { op }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
      allow(account).to receive(:apps) { [] }

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

    it 'should fail if the service does not exist' do
      allow(subject).to receive(:options) do
        { app: 'hello', environment: 'foobar' }
      end
      expect(subject).to receive(:environment_from_handle)
        .with('foobar')
        .and_return(account)
      expect(subject).to receive(:apps_from_handle).and_return(apps)
      allow(Aptible::Api::App).to receive(:all) { apps }

      expect do
        subject.send('apps:scale', 'potato', 1)
      end.to raise_error(Thor::Error, /Service.* potato.* does not exist/)
    end

    context 'no service' do
      let(:services) { [] }

      it 'should fail if the app has no services' do
        expect(subject).to receive(:environment_from_handle)
          .with('foobar')
          .and_return(account)
        expect(subject).to receive(:apps_from_handle).and_return(apps)
        allow(subject).to receive(:options) do
          { app: 'hello', environment: 'foobar' }
        end

        allow(Aptible::Api::App).to receive(:all) { apps }

        expect do
          subject.send('apps:scale', 'web', 1)
        end.to raise_error(Thor::Error, /deploy the app first/)
      end
    end
  end

  describe 'ensure_app' do
    let(:app) { apps.first }

    let(:stub_remote) { {} }
    let(:stub_env) { nil }
    let(:stub_apps) { [] }

    before do
      allow(subject).to receive(:handles_from_remote).and_return(stub_remote)
      allow(subject).to receive(:environment_from_handle).and_return(stub_env)
      allow(subject).to receive(:apps_from_handle).and_return(stub_apps)
    end

    context 'with handles from remote' do
      let(:stub_remote) do
        { app_handle: app.handle, environment_handle: account.handle }
      end

      it 'fails if it cannot find the environment' do
        expect { subject.ensure_app }.to raise_error(/Could not find env/)
      end

      context 'with an environment' do
        let(:stub_env) { account }

        it 'fails if it cannot find an app, and explains its guess' do
          err = /Could not.*app hello.*environment aptible.*remote aptible/
          expect { subject.ensure_app }.to raise_error(err)
        end

        it 'fails but does not explain its guess if it did not guess' do
          e = 'Could not find app hello in environment aptible'
          expect { subject.ensure_app(environment: 'aptible') }
            .to raise_error(e)
        end

        context 'with an app' do
          let(:stub_apps) { apps }

          it 'succeeds if it finds the app' do
            expect(subject.ensure_app).to eq(app)
          end
        end
      end
    end

    context 'without handles from remote' do
      it 'fails without further handle info' do
        expect { subject.ensure_app }
          .to raise_error(/Could not find app in current/)
      end

      it "fails when passed an environment that's not found" do
        expect { subject.ensure_app(app: 'hello', environment: 'aptible') }
          .to raise_error('Could not find environment aptible')
      end

      it "fails when passed an app that's not found" do
        expect { subject.ensure_app(app: 'hello') }
          .to raise_error('Could not find app hello')
      end

      context 'with an app' do
        let(:stub_apps) { apps }

        it 'succeeds when passed a app handle' do
          expect(subject.ensure_app(app: 'hello')).to eq(app)
        end
      end
    end
  end
end

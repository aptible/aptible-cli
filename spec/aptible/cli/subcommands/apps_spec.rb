require 'spec_helper'

class App < OpenStruct
end

class Service < OpenStruct
end

class Operation < OpenStruct
end

class Account < OpenStruct
end

def dummy_strategy_factory(app_handle, env_handle, usable,
                           options_receiver = [])
  Class.new do
    attr_reader :options

    define_method(:initialize) { |options| options_receiver << options }
    define_method(:app_handle) { app_handle }
    define_method(:env_handle) { env_handle }
    define_method(:usable?) { usable }

    def explain
      '(options from dummy)'
    end
  end
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

  describe '#ensure_app' do
    it 'fails if no usable strategy is found' do
      strategies = [dummy_strategy_factory(nil, nil, false)]
      subject.stub(:handle_strategies) { strategies }

      expect { subject.ensure_app }.to raise_error(/Could not find app/)
    end

    it 'fails if an environment is specified but not found' do
      strategies = [dummy_strategy_factory('hello', 'aptible', true)]
      subject.stub(:handle_strategies) { strategies }

      expect(subject).to receive(:environment_from_handle).and_return(nil)

      expect { subject.ensure_app }.to raise_error(/Could not find environment/)
    end

    context 'with apps' do
      before do
        account.apps = apps
        allow(Aptible::Api::App).to receive(:all).and_return(apps)
      end

      it 'scopes the app search to an environment if provided' do
        strategies = [dummy_strategy_factory('hello', 'aptible', true)]
        subject.stub(:handle_strategies) { strategies }

        expect(subject).to receive(:environment_from_handle).with('aptible')
          .and_return(account)

        expect(subject.ensure_app).to eq(apps.first)
      end

      it 'does not scope the app search to an environment if not provided' do
        strategies = [dummy_strategy_factory('hello', nil, true)]
        subject.stub(:handle_strategies) { strategies }

        expect(subject.ensure_app).to eq(apps.first)
      end

      it 'fails if no app is found' do
        apps.pop

        strategies = [dummy_strategy_factory('hello', nil, true)]
        subject.stub(:handle_strategies) { strategies }

        expect { subject.ensure_app }.to raise_error(/not find app hello/)
      end

      it 'explains the strategy when it fails' do
        apps.pop

        strategies = [dummy_strategy_factory('hello', nil, true)]
        subject.stub(:handle_strategies) { strategies }

        expect { subject.ensure_app }.to raise_error(/from dummy/)
      end

      it 'indicates the environment when the app search was scoped' do
        apps.pop

        strategies = [dummy_strategy_factory('hello', 'aptible', true)]
        subject.stub(:handle_strategies) { strategies }

        expect(subject).to receive(:environment_from_handle).with('aptible')
          .and_return(account)

        expect { subject.ensure_app }.to raise_error(/in environment aptible/)
      end

      it 'fails if multiple apps are found' do
        apps << App.new(handle: 'hello')

        strategies = [dummy_strategy_factory('hello', nil, true)]
        subject.stub(:handle_strategies) { strategies }

        expect { subject.ensure_app }.to raise_error(/Multiple apps/)
      end

      it 'falls back to another strategy when the first one is unusable' do
        strategies = [
          dummy_strategy_factory('hello', nil, false),
          dummy_strategy_factory('hello', nil, true)
        ]
        subject.stub(:handle_strategies) { strategies }

        expect(subject.ensure_app).to eq(apps.first)
      end

      it 'passes options to the strategy' do
        receiver = []
        strategies = [dummy_strategy_factory('hello', nil, false, receiver)]
        subject.stub(:handle_strategies) { strategies }

        options = { app: 'foo', environment: 'bar' }
        expect { subject.ensure_app options }.to raise_error(/not find app/)

        expect(receiver).to eq([options])
      end
    end
  end
end

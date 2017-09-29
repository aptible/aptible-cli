require 'spec_helper'

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
  before do
    allow(subject).to receive(:ask)
    allow(subject).to receive(:save_token)
    allow(subject).to receive(:attach_to_operation_logs)
    allow(subject).to receive(:fetch_token) { double 'token' }
  end

  let!(:account) { Fabricate(:account) }
  let!(:app) { Fabricate(:app, handle: 'hello', account: account) }
  let!(:service) { Fabricate(:service, app: app, process_type: 'web') }
  let(:op) { Fabricate(:operation, status: 'succeeded', resource: app) }

  describe '#apps:scale' do
    before do
      allow(Aptible::Api::App).to receive(:all) { [app] }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
    end

    context 'with environment and app' do
      let(:base_options) { { app: 'hello', environment: 'foobar' } }

      before do
        expect(subject).to receive(:environment_from_handle)
          .with('foobar')
          .and_return(account)

        expect(subject).to receive(:apps_from_handle)
          .with('hello', account)
          .and_return([app])
      end

      def stub_options(**opts)
        allow(subject).to receive(:options).and_return(base_options.merge(opts))
      end

      it 'should scale container size and count together' do
        stub_options(container_count: 3, container_size: 1024)
        expect($stderr).not_to receive(:puts)
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_count: 3, container_size: 1024)
          .and_return(op)
        subject.send('apps:scale', 'web')
      end

      it 'should scale container count alone' do
        stub_options(container_count: 3)
        expect($stderr).not_to receive(:puts)
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_count: 3)
          .and_return(op)
        subject.send('apps:scale', 'web')
      end

      it 'should scale container size alone' do
        stub_options(container_size: 1024)
        expect($stderr).not_to receive(:puts)
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_size: 1024)
          .and_return(op)
        subject.send('apps:scale', 'web')
      end

      it 'should fail if neither container_count nor container_size is set' do
        stub_options
        expect { subject.send('apps:scale', 'web') }
          .to raise_error(/provide at least/im)
      end

      it 'should scale container count (legacy)' do
        stub_options
        expect($stderr).to receive(:puts).once
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_count: 3)
          .and_return(op)
        subject.send('apps:scale', 'web', '3')
      end

      it 'should scale container size (legacy)' do
        stub_options(size: 90210)
        expect($stderr).to receive(:puts).once
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_size: 90210)
          .and_return(op)
        subject.send('apps:scale', 'web')
      end

      it 'should fail when using both current and legacy count' do
        stub_options(container_count: 2)
        expect { subject.send('apps:scale', 'web', '3') }
          .to raise_error(/count was passed via both/im)
      end

      it 'should fail when using both current and legacy size' do
        stub_options(container_size: 1024, size: 512)
        expect { subject.send('apps:scale', 'web') }
          .to raise_error(/size was passed via both/im)
      end

      it 'should fail when using too many arguments' do
        stub_options
        expect { subject.send('apps:scale', 'web', '3', '4') }
          .to raise_error(/usage:.*apps:scale/im)
      end

      it 'should fail if the service does not exist' do
        stub_options(container_count: 2)

        expect { subject.send('apps:scale', 'potato') }
          .to raise_error(Thor::Error, /Service.* potato.* does not exist/)
      end

      it 'should fail if the app has no services' do
        app.services = []
        stub_options(container_count: 2)

        expect { subject.send('apps:scale', 'web') }
          .to raise_error(Thor::Error, /deploy the app first/)
      end
    end

    it 'should fail if environment is non-existent' do
      allow(subject).to receive(:options) do
        { environment: 'foo', app: 'web', container_count: 2 }
      end
      allow(Aptible::Api::Account).to receive(:all) { [] }
      allow(service).to receive(:create_operation!) { op }

      expect do
        subject.send('apps:scale', 'web')
      end.to raise_error(Thor::Error)
    end

    it 'should fail if app is non-existent' do
      allow(subject).to receive(:options) { { container_count: 2 } }
      expect do
        subject.send('apps:scale', 'web')
      end.to raise_error(Thor::Error)
    end

    it 'should fail if number is not a valid number (legacy)' do
      expect($stderr).to receive(:puts).once
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(service).to receive(:create_operation) { op }

      expect do
        subject.send('apps:scale', 'web', 'potato')
      end.to raise_error(ArgumentError)
    end
  end

  describe '#config:set' do
    before do
      allow(Aptible::Api::App).to receive(:all) { [app] }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
    end

    it 'should reject environment variables that start with -' do
      allow(subject).to receive(:options) { { app: 'hello' } }

      expect { subject.send('config:set', '-foo=bar') }
        .to raise_error(/invalid argument/im)
    end
  end

  describe '#config:rm' do
    before do
      allow(Aptible::Api::App).to receive(:all) { [app] }
      allow(Aptible::Api::Account).to receive(:all) { [account] }
    end

    it 'should reject environment variables that start with -' do
      allow(subject).to receive(:options) { { app: 'hello' } }

      expect { subject.send('config:rm', '-foo') }
        .to raise_error(/invalid argument/im)
    end
  end

  describe '#ensure_app' do
    it 'fails if no usable strategy is found' do
      strategies = [dummy_strategy_factory(nil, nil, false)]
      allow(subject).to receive(:handle_strategies) { strategies }

      expect { subject.ensure_app }.to raise_error(/Could not find app/)
    end

    it 'fails if an environment is specified but not found' do
      strategies = [dummy_strategy_factory('hello', 'aptible', true)]
      allow(subject).to receive(:handle_strategies) { strategies }

      expect(subject).to receive(:environment_from_handle).and_return(nil)

      expect { subject.ensure_app }.to raise_error(/Could not find environment/)
    end

    context 'with apps' do
      let(:apps) { [app] }

      before do
        account.apps = apps
        allow(Aptible::Api::App).to receive(:all).and_return(apps)
      end

      it 'scopes the app search to an environment if provided' do
        strategies = [dummy_strategy_factory('hello', 'aptible', true)]
        allow(subject).to receive(:handle_strategies) { strategies }

        expect(subject).to receive(:environment_from_handle).with('aptible')
          .and_return(account)

        expect(subject.ensure_app).to eq(apps.first)
      end

      it 'does not scope the app search to an environment if not provided' do
        strategies = [dummy_strategy_factory('hello', nil, true)]
        allow(subject).to receive(:handle_strategies) { strategies }

        expect(subject.ensure_app).to eq(apps.first)
      end

      it 'fails if no app is found' do
        apps.pop

        strategies = [dummy_strategy_factory('hello', nil, true)]
        allow(subject).to receive(:handle_strategies) { strategies }

        expect { subject.ensure_app }.to raise_error(/not find app hello/)
      end

      it 'explains the strategy when it fails' do
        apps.pop

        strategies = [dummy_strategy_factory('hello', nil, true)]
        allow(subject).to receive(:handle_strategies) { strategies }

        expect { subject.ensure_app }.to raise_error(/from dummy/)
      end

      it 'indicates the environment when the app search was scoped' do
        apps.pop

        strategies = [dummy_strategy_factory('hello', 'aptible', true)]
        allow(subject).to receive(:handle_strategies) { strategies }

        expect(subject).to receive(:environment_from_handle).with('aptible')
          .and_return(account)

        expect { subject.ensure_app }.to raise_error(/in environment aptible/)
      end

      it 'fails if multiple apps are found' do
        apps << Fabricate(:app, handle: 'hello')

        strategies = [dummy_strategy_factory('hello', nil, true)]
        allow(subject).to receive(:handle_strategies) { strategies }

        expect { subject.ensure_app }.to raise_error(/Multiple apps/)
      end

      it 'falls back to another strategy when the first one is unusable' do
        strategies = [
          dummy_strategy_factory('hello', nil, false),
          dummy_strategy_factory('hello', nil, true)
        ]
        allow(subject).to receive(:handle_strategies) { strategies }

        expect(subject.ensure_app).to eq(apps.first)
      end

      it 'passes options to the strategy' do
        receiver = []
        strategies = [dummy_strategy_factory('hello', nil, false, receiver)]
        allow(subject).to receive(:handle_strategies) { strategies }

        options = { app: 'foo', environment: 'bar' }
        expect { subject.ensure_app options }.to raise_error(/not find app/)

        expect(receiver).to eq([options])
      end
    end
  end
end

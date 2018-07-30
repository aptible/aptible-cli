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
    allow(subject).to receive(:save_token)
    allow(subject).to receive(:attach_to_operation_logs)
    allow(subject).to receive(:fetch_token) { double 'token' }
  end

  let!(:account) { Fabricate(:account) }
  let!(:app) { Fabricate(:app, handle: 'hello', account: account) }
  let!(:service) { Fabricate(:service, app: app, process_type: 'web') }
  let(:op) { Fabricate(:operation, status: 'succeeded', resource: app) }

  describe '#apps' do
    it 'lists an app in an account' do
      allow(Aptible::Api::Account).to receive(:all).and_return([account])
      subject.send('apps')

      expect(captured_output_text)
        .to eq("=== #{account.handle}\n#{app.handle}\n")
    end

    it 'lists multiple apps in an account' do
      allow(Aptible::Api::Account).to receive(:all).and_return([account])
      app2 = Fabricate(:app, handle: 'foobar', account: account)
      subject.send('apps')

      expect(captured_output_text)
        .to eq("=== #{account.handle}\n#{app.handle}\n#{app2.handle}\n")
    end

    it 'lists multiple apps, grouped by account in text output' do
      account1 = Fabricate(:account, handle: 'Aaccount1')
      app11 = Fabricate(:app, account: account1, handle: 'app11')

      account2 = Fabricate(:account, handle: 'Baccount2')
      app21 = Fabricate(:app, account: account2, handle: 'app21')
      app22 = Fabricate(:app, account: account2, handle: 'app21')

      allow(Aptible::Api::Account).to receive(:all)
        .and_return([account1, account2])

      subject.send('apps')

      expected_text = [
        "=== #{account1.handle}",
        app11.handle,
        '',
        "=== #{account2.handle}",
        app21.handle,
        app22.handle,
        ''
      ].join("\n")

      expect(captured_output_text).to eq(expected_text)
    end

    it 'lists filters down to one account' do
      account2 = Fabricate(:account, handle: 'account2')
      app2 = Fabricate(:app, account: account2, handle: 'app2')
      allow(subject).to receive(:options)
        .and_return(environment: account2.handle)

      allow(Aptible::Api::Account).to receive(:all)
        .and_return([account, account2])
      subject.send('apps')

      expect(captured_output_text)
        .to eq("=== #{account2.handle}\n#{app2.handle}\n")
    end

    it 'includes services in JSON' do
      account = Fabricate(:account, handle: 'account')
      app = Fabricate(:app, account: account, handle: 'app')
      allow(Aptible::Api::Account).to receive(:all).and_return([account])

      s1 = Fabricate(
        :service,
        app: app, process_type: 's1', command: 'true', container_count: 2
      )
      s2 = Fabricate(
        :service,
        app: app, process_type: 's2', container_memory_limit_mb: 2048
      )

      expected_json = [
        {
          'environment' => {
            'id' => account.id,
            'handle' => account.handle
          },
          'handle' => app.handle,
          'id' => app.id,
          'status' => app.status,
          'git_remote' => app.git_repo,
          'services' => [
            {
              'service' => s1.process_type,
              'id' => s1.id,
              'command' => s1.command,
              'container_count' => s1.container_count,
              'container_size' => s1.container_memory_limit_mb
            },
            {
              'service' => s2.process_type,
              'id' => s2.id,
              'command' => 'CMD',
              'container_count' => s2.container_count,
              'container_size' => s2.container_memory_limit_mb
            }
          ]
        }
      ]

      subject.send('apps')

      expect(captured_output_json).to eq(expected_json)
    end

    it 'includes the last deploy operation in JSON' do
      account = Fabricate(:account, handle: 'account')
      op = Fabricate(:operation, type: 'deploy', status: 'succeeded')
      app = Fabricate(:app, account: account, handle: 'app',
                            last_deploy_operation: op)
      allow(Aptible::Api::Account).to receive(:all).and_return([account])

      expected_json = [
        {
          'environment' => {
            'id' => account.id,
            'handle' => account.handle
          },
          'handle' => app.handle,
          'id' => app.id,
          'status' => app.status,
          'git_remote' => app.git_repo,
          'last_deploy_operation' =>
            {
              'id' => op.id,
              'status' => op.status,
              'git_ref' => op.git_ref,
              'user_email' => op.user_email,
              'created_at' => op.created_at
            },
          'services' => []
        }
      ]

      subject.send('apps')

      expect(captured_output_json).to eq(expected_json)
    end
  end

  describe '#apps:create' do
    before do
      allow(Aptible::Api::Account).to receive(:all) { [account] }
    end

    it 'creates an app' do
      expect(account).to receive(:create_app)
        .with(handle: 'foo').and_return(app)

      subject.send('apps:create', 'foo')
    end

    it 're-raises errors' do
      app.errors.full_messages << 'oops'
      expect(account).to receive(:create_app)
        .with(handle: 'foo').and_return(app)

      expect { subject.send('apps:create', 'foo') }
        .to raise_error(Thor::Error, /oops/i)
    end
  end

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
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_count: 3, container_size: 1024)
          .and_return(op)
        subject.send('apps:scale', 'web')
        expect(captured_logs).not_to match(/deprecated/i)
      end

      it 'should scale container count alone' do
        stub_options(container_count: 3)
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_count: 3)
          .and_return(op)
        subject.send('apps:scale', 'web')
        expect(captured_logs).not_to match(/deprecated/i)
      end

      it 'should scale container size alone' do
        stub_options(container_size: 1024)
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_size: 1024)
          .and_return(op)
        subject.send('apps:scale', 'web')
        expect(captured_logs).not_to match(/deprecated/i)
      end

      it 'should fail if neither container_count nor container_size is set' do
        stub_options
        expect { subject.send('apps:scale', 'web') }
          .to raise_error(/provide at least/im)
      end

      it 'should scale container count (legacy)' do
        stub_options
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_count: 3)
          .and_return(op)
        subject.send('apps:scale', 'web', '3')
        expect(captured_logs).to match(/deprecated/i)
      end

      it 'should scale container size (legacy)' do
        stub_options(size: 90210)
        expect(service).to receive(:create_operation!)
          .with(type: 'scale', container_size: 90210)
          .and_return(op)
        subject.send('apps:scale', 'web')
        expect(captured_logs).to match(/deprecated/i)
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
      allow(subject).to receive(:options) { { app: 'hello' } }
      allow(service).to receive(:create_operation) { op }

      expect do
        subject.send('apps:scale', 'web', 'potato')
      end.to raise_error(ArgumentError)

      expect(captured_logs).to match(/deprecated/i)
    end
  end

  describe '#apps:deprovision' do
    let(:operation) { Fabricate(:operation, resource: app) }

    before { allow(subject).to receive(:ensure_app).and_return(app) }

    it 'deprovisions an app' do
      expect(app).to receive(:create_operation!)
        .with(type: 'deprovision').and_return(operation)

      expect(subject).to receive(:attach_to_operation_logs).with(operation)

      subject.send('apps:deprovision')
    end
    it 'does not fail if the operation cannot be found' do
      expect(app).to receive(:create_operation!)
        .with(type: 'deprovision').and_return(operation)

      response = Faraday::Response.new(status: 404)
      error = HyperResource::ClientError.new('Not Found', response: response)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)
        .and_raise(error)

      subject.send('apps:deprovision')
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

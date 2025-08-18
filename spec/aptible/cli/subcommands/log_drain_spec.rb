require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:account) { Fabricate(:account) }
  let!(:log_drain) do
    Fabricate(:log_drain, handle: 'test', account: account)
  end

  let(:token) { double('token') }
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  before do
    allow(Aptible::Api::LogDrain).to receive(:all)
      .with(token: token, href: '/log_drains?per_page=5000')
      .and_return([log_drain])

    allow(Aptible::Api::Account).to receive(:all)
      .with(token: token, href: '/accounts?per_page=5000&no_embed=true')
      .and_return([account])
  end

  describe '#log_drain:list' do
    it 'lists a log drains for an account' do
      subject.send('log_drain:list')

      out = "=== aptible\n" \
            "test\n"
      expect(captured_output_text).to eq(out)
    end

    it 'lists log drains across multiple accounts' do
      other_account = Fabricate(:account)
      other_drain = Fabricate(
        :log_drain,
        handle: 'test2',
        account: other_account
      )
      accounts = [account, other_account]

      allow(Aptible::Api::LogDrain).to receive(:all)
        .with(token: token, href: '/log_drains?per_page=5000')
        .and_return([log_drain, other_drain])
      allow(Aptible::Api::Account).to receive(:all).and_return(accounts)

      subject.send('log_drain:list')

      out = "=== aptible\n" \
            "test\n" \
            "test2\n"
      expect(captured_output_text).to eq(out)
    end

    it 'lists log drains for a single account when --environment is included' do
      other_account = Fabricate(:account)
      Fabricate(:log_drain, handle: 'test2', account: other_account)
      accounts = [account, other_account]
      allow(Aptible::Api::Account).to receive(:all).and_return(accounts)

      subject.options = { environment: account.handle }
      subject.send('log_drain:list')

      out = "=== aptible\n" \
            "test\n"
      expect(captured_output_text).to eq(out)
    end
  end

  describe '#log_drain:create' do
    def expect_provision_log_drain(create_opts, provision_opts = {})
      log_drain = Fabricate(:log_drain, account: account)
      op = Fabricate(:operation)

      expect(account).to receive(:create_log_drain!)
        .with(**create_opts).and_return(log_drain)

      expect(log_drain).to receive(:create_operation)
        .with(type: :provision, **provision_opts).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)
    end

    context 'elasticsearch' do
      let(:db) { Fabricate(:database, account: account, id: 5) }

      it 'creates a new Elasticsearch log drain' do
        opts = {
          handle: 'test',
          drain_apps: nil,
          drain_databases: nil,
          drain_ephemeral_sessions: nil,
          drain_proxies: nil,
          drain_type: :elasticsearch_database,
          logging_token: nil,
          database_id: db.id
        }
        expect_provision_log_drain(opts)

        subject.options = {
          db: db.handle,
          environment: account.handle
        }
        subject.send('log_drain:create:elasticsearch', 'test')
      end

      it 'creates a new Elasticsearch log drain with a pipeline' do
        opts = {
          handle: 'test-es',
          drain_apps: nil,
          drain_databases: nil,
          drain_ephemeral_sessions: nil,
          drain_proxies: nil,
          drain_type: :elasticsearch_database,
          logging_token: 'test-pipeline',
          database_id: db.id
        }
        expect_provision_log_drain(opts)

        subject.options = {
          db: db.handle,
          environment: account.handle,
          pipeline: 'test-pipeline'
        }
        subject.send('log_drain:create:elasticsearch', 'test-es')
      end
    end

    # HTTPS, Datadog, Sumologic, and LogDNA are all similar enough
    # that they're not tested individually
    context 'https' do
      it 'creates a new HTTPS log drain' do
        opts = {
          handle: 'test-https',
          drain_apps: nil,
          drain_databases: nil,
          drain_ephemeral_sessions: nil,
          drain_proxies: nil,
          drain_type: :https_post,
          url: 'https://test.foo.com'
        }
        expect_provision_log_drain(opts)

        subject.options = {
          environment: account.handle,
          url: 'https://test.foo.com'
        }
        subject.send('log_drain:create:https', 'test-https')
      end
    end

    # Syslog and Papertrail are similar enough that they're
    # not tested individually
    context 'syslog' do
      it 'creates a new syslog log drain' do
        opts = {
          handle: 'test-syslog',
          drain_host: 'test.foo.com',
          drain_port: 2468,
          logging_token: nil,
          drain_apps: nil,
          drain_databases: nil,
          drain_ephemeral_sessions: nil,
          drain_proxies: nil,
          drain_type: :syslog_tls_tcp
        }
        expect_provision_log_drain(opts)

        subject.options = {
          environment: account.handle,
          host: 'test.foo.com',
          port: 2468
        }
        subject.send('log_drain:create:syslog', 'test-syslog')
      end

      it 'creates a new syslog log drain with a logging token' do
        opts = {
          handle: 'test-syslog',
          drain_host: 'test.foo.com',
          drain_port: 2468,
          logging_token: 'test-token',
          drain_apps: nil,
          drain_databases: nil,
          drain_ephemeral_sessions: nil,
          drain_proxies: nil,
          drain_type: :syslog_tls_tcp
        }
        expect_provision_log_drain(opts)

        subject.options = {
          environment: account.handle,
          host: 'test.foo.com',
          port: 2468,
          token: 'test-token'
        }
        subject.send('log_drain:create:syslog', 'test-syslog')
      end
    end

    describe 'solarwinds' do
      it 'creates a new Solarwinds log drain' do
        opts = {
          handle: 'test-solarwinds',
          drain_host: 'some-solarwinds.domain.com',
          logging_token: 'test-token',
          drain_apps: nil,
          drain_databases: nil,
          drain_ephemeral_sessions: nil,
          drain_proxies: nil,
          drain_type: :solarwinds
        }

        expect_provision_log_drain(opts)

        subject.options = {
          environment: account.handle,
          host: 'some-solarwinds.domain.com',
          token: 'test-token'
        }
        subject.send('log_drain:create:solarwinds', 'test-solarwinds')
      end
    end
  end

  describe '#log_drain:deprovision' do
    let(:operation) { Fabricate(:operation, resource: log_drain) }

    it 'deprovisions a log drain' do
      expect(log_drain).to receive(:create_operation)
        .with(type: :deprovision).and_return(operation)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)
      subject.send('log_drain:deprovision', log_drain.handle)
    end

    it 'does not fail if the operation cannot be found' do
      expect(log_drain).to receive(:create_operation)
        .with(type: :deprovision).and_return(operation)
      response = Faraday::Response.new(status: 404)
      error = HyperResource::ClientError.new('Not Found', response: response)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)
        .and_raise(error)
      subject.send('log_drain:deprovision', log_drain.handle)
    end
  end
end

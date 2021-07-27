require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:account) { Fabricate(:account) }
  let!(:metric_drain) do
    Fabricate(:metric_drain, handle: 'test', account: account)
  end

  let(:token) { double('token') }
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  before do
    allow(Aptible::Api::Account).to receive(:all)
      .with(token: token).and_return([account])
  end

  describe '#metric_drain:list' do
    it 'lists a metric drains for an account' do
      subject.send('metric_drain:list')

      out = "=== aptible\n" \
            "test\n"
      expect(captured_output_text).to eq(out)
    end

    it 'lists metric drains across multiple accounts' do
      other_account = Fabricate(:account)
      Fabricate(:metric_drain, handle: 'test2', account: other_account)
      accounts = [account, other_account]
      allow(Aptible::Api::Account).to receive(:all).and_return(accounts)

      subject.send('metric_drain:list')

      out = "=== aptible\n" \
            "test\n" \
            "test2\n"
      expect(captured_output_text).to eq(out)
    end

    it 'lists metric drains for a single account with --environment' do
      other_account = Fabricate(:account)
      Fabricate(:metric_drain, handle: 'test2', account: other_account)
      accounts = [account, other_account]
      allow(Aptible::Api::Account).to receive(:all).and_return(accounts)

      subject.options = { environment: account.handle }
      subject.send('metric_drain:list')

      out = "=== aptible\n" \
            "test\n"
      expect(captured_output_text).to eq(out)
    end
  end

  describe '#metric_drain:create' do
    def expect_provision_metric_drain(create_opts, provision_opts = {})
      metric_drain = Fabricate(:metric_drain, account: account)
      op = Fabricate(:operation)

      expect(account).to receive(:create_metric_drain!)
        .with(**create_opts).and_return(metric_drain)

      expect(metric_drain).to receive(:create_operation)
        .with(type: :provision, **provision_opts).and_return(op)

      expect(subject).to receive(:attach_to_operation_logs).with(op)
    end

    context 'influxdb' do
      let(:db) { Fabricate(:database, account: account, id: 5) }

      it 'creates a new InfluxDB metric drain' do
        opts = {
          handle: 'test-influxdb',
          drain_type: :influxdb_database,
          database_id: db.id
        }
        expect_provision_metric_drain(opts)

        subject.options = {
          db: db.handle,
          environment: account.handle
        }
        subject.send('metric_drain:create:influxdb', 'test-influxdb')
      end
    end

    context 'influxdb:custom' do
      it 'creates a new InfluxDB metric drain' do
        opts = {
          handle: 'test-influxdb-custom',
          drain_type: :influxdb,
          drain_configuration: {
            address: 'https://test.foo.com:443',
            database: 'foobar',
            password: 'bar',
            username: 'foo'
          }
        }
        expect_provision_metric_drain(opts)

        subject.options = {
          environment: account.handle,
          username: 'foo',
          password: 'bar',
          db: 'foobar',
          url: 'https://test.foo.com:443'
        }
        subject.send('metric_drain:create:influxdb:custom',
                     'test-influxdb-custom')
      end
    end

    context 'datadog' do
      it 'creates a new Datadog metric drain' do
        opts = {
          handle: 'test-datadog',
          drain_type: :datadog,
          drain_configuration: {
            api_key: 'foobar'
          }
        }
        expect_provision_metric_drain(opts)

        subject.options = {
          environment: account.handle,
          api_key: 'foobar'
        }
        subject.send('metric_drain:create:datadog', 'test-datadog')
      end

      it 'raises an error when the custom series url is invalid' do
        subject.options = {
          environment: account.handle,
          api_key: 'foobar',
          site: 'BAD'
        }
        expect { subject.send('metric_drain:create:datadog', 'test-datadog') }
          .to raise_error(Thor::Error, /Invalid site/i)
      end

      it 'creates a new Datadog metric drain with a custom series url' do
        opts = {
          handle: 'test-datadog',
          drain_type: :datadog,
          drain_configuration: {
            api_key: 'foobar',
            series_url: 'https://app.datadoghq.eu'
          }
        }
        expect_provision_metric_drain(opts)

        subject.options = {
          environment: account.handle,
          api_key: 'foobar',
          site: 'EU1'
        }
        subject.send('metric_drain:create:datadog', 'test-datadog')
      end
    end
  end

  describe '#metric_drain:deprovision' do
    let(:operation) { Fabricate(:operation, resource: metric_drain) }

    it 'deprovisions a log drain' do
      expect(metric_drain).to receive(:create_operation)
        .with(type: :deprovision).and_return(operation)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)
      subject.send('metric_drain:deprovision', metric_drain.handle)
    end

    it 'does not fail if the operation cannot be found' do
      expect(metric_drain).to receive(:create_operation)
        .with(type: :deprovision).and_return(operation)
      response = Faraday::Response.new(status: 404)
      error = HyperResource::ClientError.new('Not Found', response: response)
      expect(subject).to receive(:attach_to_operation_logs).with(operation)
        .and_raise(error)
      subject.send('metric_drain:deprovision', metric_drain.handle)
    end
  end
end

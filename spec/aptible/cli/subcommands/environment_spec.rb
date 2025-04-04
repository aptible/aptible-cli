require 'spec_helper'

describe Aptible::CLI::Agent do
  let!(:a1) do
    Fabricate(:account, handle: 'foo', ca_body: 'account 1 cert')
  end
  let!(:a2) do
    Fabricate(:account, handle: 'bar', ca_body: '--account 2 cert--')
  end

  let(:token) { double 'token' }

  before(:each) do
    allow(subject).to receive(:fetch_token) { token }
    allow(Aptible::Api::Account)
      .to receive(:all)
      .with(token: token, href: '/accounts?per_page=5000&no_embed=true')
      .and_return([a1, a2])
  end

  describe('#environment:list') do
    it 'lists available environments' do
      subject.send('environment:list')

      expect(captured_output_text.split("\n")).to include('foo')
      expect(captured_output_text.split("\n")).to include('bar')
    end

    it 'includes stack information in JSON output' do
      stack1 = Fabricate(
        :stack,
        name: 'stack1',
        region: 'us-east-1',
        outbound_ip_addresses: ['1.1.1.1']
      )
      stack2 = Fabricate(
        :stack,
        name: 'stack2',
        region: 'us-west-1',
        outbound_ip_addresses: ['2.2.2.2']
      )
      a1.stack = stack1
      a2.stack = stack2

      subject.send('environment:list')

      expected_json = [
        {
          'id' => a1.id,
          'handle' => 'foo',
          'created_at' => fmt_time(a1.created_at),
          'stack' => {
            'id' => stack1.id,
            'name' => 'stack1',
            'region' => 'us-east-1',
            'outbound_ip_addresses' => ['1.1.1.1']
          }
        },
        {
          'id' => a2.id,
          'handle' => 'bar',
          'created_at' => fmt_time(a2.created_at),
          'stack' => {
            'id' => stack2.id,
            'name' => 'stack2',
            'region' => 'us-west-1',
            'outbound_ip_addresses' => ['2.2.2.2']
          }
        }
      ]

      expect(captured_output_json).to eq(expected_json)
    end
  end

  describe('#environment:ca_cert') do
    it 'fetches certs for all avaliable environments' do
      subject.send('environment:ca_cert')

      expect(captured_output_text.split("\n")).to include('account 1 cert')
      expect(captured_output_text.split("\n")).to include('--account 2 cert--')

      expected_accounts = [
        {
          'handle' => 'foo',
          'ca_body' => 'account 1 cert',
          'created_at' => fmt_time(a1.created_at)
        },
        {
          'handle' => 'bar',
          'ca_body' => '--account 2 cert--',
          'created_at' => fmt_time(a2.created_at)
        }
      ]
      expect(
        captured_output_json.map! { |account| account.except('id', 'stack') }
      ).to eq(expected_accounts)
    end

    it 'fetches certs for specified environment' do
      subject.options = { environment: 'foo' }
      subject.send('environment:ca_cert')

      expect(captured_output_text.split("\n")).to include('account 1 cert')
      expect(captured_output_text.split("\n"))
        .to_not include('--account 2 cert--')
    end
  end

  describe('#environment:rename') do
    it 'should rename properly' do
      expect(a1).to receive(:update!)
        .with(handle: 'foo-renamed').and_return(a1)
      subject.send('environment:rename', 'foo', 'foo-renamed')
      expect(captured_logs).to include(
        'In order for the new environment handle (foo-renamed)'
      )
      expect(captured_logs).to include(
        '* Your own external scripts (e.g. for CI/CD)'
      )
      expect(captured_logs).to include(
        '* Git remote URLs (ex: git@beta.aptible.com:foo-renamed'
      )
    end
    it 'should fail if env does not exist' do
      expect { subject.send('environment:rename', 'foo1', 'foo2') }
        .to raise_error(/Could not find environment foo1/)
    end
    it 'should raise error if update fails' do
      response = Faraday::Response.new(status: 422)
      error = HyperResource::ClientError.new('ActiveRecord::RecordInvalid:'\
        ' Validation failed: Handle has already been taken, Handle has already'\
        ' been taken', response: response)
      expect(a1).to receive(:update!)
        .with(handle: 'bar').and_raise(error)
      expect { subject.send('environment:rename', 'foo', 'bar') }
        .to raise_error(HyperResource::ClientError)
    end
  end
end

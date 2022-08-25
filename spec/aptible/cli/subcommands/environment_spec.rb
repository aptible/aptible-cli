require 'spec_helper'

describe Aptible::CLI::Agent do
  let!(:a1) do
    Fabricate(:account, handle: 'foo', ca_body: 'account 1 cert')
  end
  let!(:a2) do
    Fabricate(:account, handle: 'bar', ca_body: '--account 2 cert--')
  end

  let(:token) { double 'token' }

  before do
    allow(subject).to receive(:fetch_token) { token }
    allow(Aptible::Api::Account).to receive(:all).with(token: token)
      .and_return([a1, a2])
  end

  it 'lists avaliable environments' do
    subject.send('environment:list')

    expect(captured_output_text.split("\n")).to include('foo')
    expect(captured_output_text.split("\n")).to include('bar')
  end

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
    expect(captured_output_json.map! { |account| account.except('id') })
      .to eq(expected_accounts)
  end

  it 'fetches certs for specified environment' do
    subject.options = { environment: 'foo' }
    subject.send('environment:ca_cert')

    expect(captured_output_text.split("\n")).to include('account 1 cert')
    expect(captured_output_text.split("\n"))
      .to_not include('--account 2 cert--')
  end
end

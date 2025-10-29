require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:account) { Fabricate(:account) }
  let!(:ai_token) do
    Fabricate(:ai_token, name: 'test-token', account: account)
  end

  let(:token) { double('token') }
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  before do
    allow(Aptible::Api::AiToken).to receive(:all)
      .with(token: token, href: '/ai_tokens?per_page=5000')
      .and_return([ai_token])

    allow(Aptible::Api::Account).to receive(:all)
      .with(token: token, href: '/accounts?per_page=5000&no_embed=true')
      .and_return([account])
  end

  describe '#ai:tokens:list' do
    it 'lists AI tokens for an account' do
      subject.send('ai:tokens:list')

      out = "=== aptible\n" \
            "#{ai_token.id}\n"
      expect(captured_output_text).to eq(out)
    end

    it 'lists AI tokens across multiple accounts' do
      other_account = Fabricate(:account)
      other_token = Fabricate(
        :ai_token,
        name: 'test-token-2',
        account: other_account
      )
      accounts = [account, other_account]

      allow(Aptible::Api::AiToken).to receive(:all)
        .with(token: token, href: '/ai_tokens?per_page=5000')
        .and_return([ai_token, other_token])
      allow(Aptible::Api::Account).to receive(:all).and_return(accounts)

      subject.send('ai:tokens:list')

      out = "=== aptible\n" \
            "#{ai_token.id}\n" \
            "#{other_token.id}\n"
      expect(captured_output_text).to eq(out)
    end
  end

  describe '#ai:tokens:create' do
    let(:created_token) do
      Fabricate(:ai_token, name: 'new-token', account: account)
    end

    before do
      allow(subject).to receive(:ensure_environment).and_return(account)
      allow(account).to receive(:create_ai_token!).and_return(created_token)
    end

    it 'creates an AI token' do
      subject.options = { name: 'new-token' }
      subject.send('ai:tokens:create')

      expect(account).to have_received(:create_ai_token!)
        .with(name: 'new-token')
    end

    it 'creates an AI token without a name' do
      subject.options = {}
      subject.send('ai:tokens:create')

      expect(account).to have_received(:create_ai_token!).with({})
    end
  end

  describe '#ai:tokens:revoke' do
    let(:operation) { Fabricate(:operation) }

    before do
      allow(Aptible::Api::AiToken).to receive(:find)
        .with(ai_token.id, token: token)
        .and_return(ai_token)
      allow(ai_token).to receive(:create_operation!)
        .and_return(operation)
      allow(subject).to receive(:attach_to_operation_logs)
    end

    it 'revokes an AI token' do
      subject.send('ai:tokens:revoke', ai_token.id)

      expect(Aptible::Api::AiToken).to have_received(:find)
        .with(ai_token.id, token: token)
      expect(ai_token).to have_received(:create_operation!)
        .with(type: 'revoke')
      expect(subject).to have_received(:attach_to_operation_logs)
        .with(operation)
    end

    it 'raises an error if the token is not found' do
      allow(Aptible::Api::AiToken).to receive(:find)
        .with('nonexistent', token: token)
        .and_return(nil)

      expect { subject.send('ai:tokens:revoke', 'nonexistent') }
        .to raise_error(/AI token nonexistent not found/)
    end

    it 'handles 404 errors gracefully' do
      allow(subject).to receive(:attach_to_operation_logs)
        .and_raise(
          HyperResource::ClientError.new(
            'Not Found',
            response: double(status: 404)
          )
        )

      expect { subject.send('ai:tokens:revoke', ai_token.id) }
        .not_to raise_error
    end
  end
end


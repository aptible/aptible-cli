require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:account) { Fabricate(:account) }
  let(:token) { double('token') }

  before { allow(subject).to receive(:fetch_token).and_return(token) }

  describe '#ai:tokens:list' do
    let!(:ai_token) do
      Fabricate(:ai_token, name: 'test-token', account: account)
    end

    before do
      allow(subject).to receive(:scoped_environments).with({}).and_return([account])
    end

    it 'lists AI tokens for an account' do
      expect { subject.send('ai:tokens:list') }.not_to raise_error
    end

    it 'lists AI tokens across multiple accounts' do
      other_account = Fabricate(:account)
      Fabricate(:ai_token, name: 'test-token-2', account: other_account)

      allow(subject).to receive(:scoped_environments).with({})
        .and_return([account, other_account])

      expect { subject.send('ai:tokens:list') }.not_to raise_error
    end

    it 'skips accounts when endpoint returns 404' do
      error_response = double('error_response', status: 404, body: 'Not Found')
      error = HyperResource::ClientError.new('Not Found', response: error_response)

      allow(account).to receive(:ai_tokens).and_raise(error)

      expect { subject.send('ai:tokens:list') }.not_to raise_error
    end
  end

  describe '#ai:tokens:create' do
    let(:created_token) do
      Fabricate(:ai_token, name: 'new-token', account: account)
    end

    before do
      allow(subject).to receive(:ensure_environment).and_return(account)
    end

    it 'creates an AI token with a name' do
      expect(account).to receive(:create_ai_token!)
        .with(name: 'new-token').and_return(created_token)

      subject.options = { name: 'new-token' }
      expect { subject.send('ai:tokens:create') }.not_to raise_error

      expect(captured_logs).to include('Save the token value now')
    end

    it 'creates an AI token without a name' do
      expect(account).to receive(:create_ai_token!)
        .with({}).and_return(created_token)

      subject.options = {}
      subject.send('ai:tokens:create')

      expect(captured_logs).to include('Save the token value now')
    end

    it 'warns user to save token value if present' do
      token_with_value = Fabricate(:ai_token, name: 'new-token', account: account)
      allow(token_with_value).to receive(:attributes)
        .and_return({ 'token' => 'sk-secret-value' })

      expect(account).to receive(:create_ai_token!)
        .with(name: 'new-token').and_return(token_with_value)

      subject.options = { name: 'new-token' }
      subject.send('ai:tokens:create')

      expect(captured_logs).to include('Save the token value now - it will not be shown again!')
    end
  end

  describe '#ai:tokens:show' do
    let(:ai_token_resource) { double('ai_token_resource') }
    let(:token_id) { 'sk-test-token-12345' }
    let(:token_response) do
      Fabricate(:ai_token, id: token_id, name: 'test-token', account: nil)
    end

    before do
      allow(Aptible::Api::Resource).to receive(:new)
        .with(token: token)
        .and_return(ai_token_resource)
      allow(ai_token_resource).to receive(:href=)
    end

    it 'shows an AI token successfully' do
      allow(ai_token_resource).to receive(:get).and_return(token_response)

      expect { subject.send('ai:tokens:show', token_id) }.not_to raise_error

      expect(ai_token_resource).to have_received(:href=).with("/ai_tokens/#{token_id}")
      expect(ai_token_resource).to have_received(:get)
    end

    it 'raises an error if the token is not found (404)' do
      error_response = double('error_response', status: 404, body: 'Not Found')
      error = HyperResource::ClientError.new('Not Found', response: error_response)
      allow(ai_token_resource).to receive(:get).and_raise(error)

      expect { subject.send('ai:tokens:show', 'nonexistent') }
        .to raise_error(Thor::Error, /AI token nonexistent not found or access denied/)
    end

    it 'raises an error on other client errors' do
      error_response = double('error_response', status: 500, body: 'Internal Server Error')
      error = HyperResource::ClientError.new('Internal Server Error', response: error_response)
      allow(ai_token_resource).to receive(:get).and_raise(error)

      expect { subject.send('ai:tokens:show', token_id) }
        .to raise_error(Thor::Error, /Failed to retrieve token/)
    end
  end

  describe '#ai:tokens:revoke' do
    let(:ai_token_resource) { double('ai_token_resource') }
    let(:token_id) { 'sk-test-token-12345' }

    before do
      allow(Aptible::Api::Resource).to receive(:new)
        .with(token: token)
        .and_return(ai_token_resource)
      allow(ai_token_resource).to receive(:href=)
    end

    it 'revokes an AI token successfully' do
      allow(ai_token_resource).to receive(:delete)

      subject.send('ai:tokens:revoke', token_id)

      expect(ai_token_resource).to have_received(:href=).with("/ai_tokens/#{token_id}")
      expect(ai_token_resource).to have_received(:delete)
      expect(captured_logs).to include('AI token revoked successfully')
    end

    it 'raises an error if the token is not found (404)' do
      error_response = double('error_response', status: 404, body: 'Not Found')
      error = HyperResource::ClientError.new('Not Found', response: error_response)
      allow(ai_token_resource).to receive(:delete).and_raise(error)

      expect { subject.send('ai:tokens:revoke', 'nonexistent') }
        .to raise_error(Thor::Error, /AI token nonexistent not found or access denied/)
    end

    it 'raises an error on other client errors' do
      error_response = double('error_response', status: 500, body: 'Internal Server Error')
      error = HyperResource::ClientError.new('Internal Server Error', response: error_response)
      allow(ai_token_resource).to receive(:delete).and_raise(error)

      expect { subject.send('ai:tokens:revoke', token_id) }
        .to raise_error(Thor::Error, /Failed to revoke token/)
    end
  end
end

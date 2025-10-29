require 'spec_helper'

describe Aptible::CLI::Agent do
  let(:account) { Fabricate(:account) }
  let(:token) { double('token') }
  
  before { allow(subject).to receive(:fetch_token).and_return(token) }

  describe '#ai:tokens:list' do
    let!(:ai_token) do
      Fabricate(:ai_token, name: 'test-token', account: account)
    end

    let(:ai_tokens_response) do
      response = double('response')
      embedded = double('embedded')
      allow(embedded).to receive(:ai_tokens).and_return([ai_token])
      allow(response).to receive(:_embedded).and_return(embedded)
      response
    end

    let(:ai_tokens_resource) { double('ai_tokens_resource') }

    before do
      allow(subject).to receive(:scoped_environments).with({}).and_return([account])
      allow(Aptible::Api::Resource).to receive(:new)
        .with(token: token)
        .and_return(ai_tokens_resource)
      allow(ai_tokens_resource).to receive(:href=)
      allow(ai_tokens_resource).to receive(:get).and_return(ai_tokens_response)
    end

    it 'lists AI tokens for an account' do
      expect { subject.send('ai:tokens:list') }.not_to raise_error

      expect(ai_tokens_resource).to have_received(:href=).with("#{account.href}/ai_tokens")
      expect(ai_tokens_resource).to have_received(:get)
    end

    it 'lists AI tokens across multiple accounts' do
      other_account = Fabricate(:account)
      other_token = Fabricate(
        :ai_token,
        name: 'test-token-2',
        account: other_account
      )

      other_response = double('other_response')
      other_embedded = double('other_embedded')
      allow(other_embedded).to receive(:ai_tokens).and_return([other_token])
      allow(other_response).to receive(:_embedded).and_return(other_embedded)

      allow(subject).to receive(:scoped_environments).with({}).and_return([account, other_account])
      
      call_count = 0
      allow(ai_tokens_resource).to receive(:get) do
        call_count += 1
        call_count == 1 ? ai_tokens_response : other_response
      end

      expect { subject.send('ai:tokens:list') }.not_to raise_error

      # Verify both accounts were queried
      expect(ai_tokens_resource).to have_received(:get).twice
    end

    it 'skips accounts when endpoint returns 404' do
      error_response = double('error_response', status: 404, body: 'Not Found')
      error = HyperResource::ClientError.new('Not Found', response: error_response)
      
      allow(ai_tokens_resource).to receive(:get).and_raise(error)

      expect { subject.send('ai:tokens:list') }.not_to raise_error
    end
  end

  describe '#ai:tokens:create' do
    let(:created_token) do
      Fabricate(:ai_token, name: 'new-token', account: account)
    end

    let(:ai_token_resource) { double('ai_token_resource') }

    before do
      allow(subject).to receive(:ensure_environment).and_return(account)
      allow(Aptible::Api::Resource).to receive(:new)
        .with(token: token)
        .and_return(ai_token_resource)
      allow(ai_token_resource).to receive(:href=)
      allow(ai_token_resource).to receive(:post).and_return(created_token)
    end

    it 'creates an AI token with a name' do
      subject.options = { name: 'new-token' }
      expect { subject.send('ai:tokens:create') }.not_to raise_error

      expect(ai_token_resource).to have_received(:href=).with("#{account.href}/ai_tokens")
      expect(ai_token_resource).to have_received(:post).with(name: 'new-token')
      expect(captured_logs).to include('Save the token value now')
    end

    it 'creates an AI token without a name' do
      subject.options = {}
      subject.send('ai:tokens:create')

      expect(ai_token_resource).to have_received(:href=).with("#{account.href}/ai_tokens")
      expect(ai_token_resource).to have_received(:post).with({})
      
      expect(captured_logs).to include('Save the token value now')
    end

    it 'warns user to save token value if present' do
      token_with_value = Fabricate(:ai_token, name: 'new-token', account: account)
      allow(token_with_value).to receive(:token).and_return('sk-secret-value')
      allow(ai_token_resource).to receive(:post).and_return(token_with_value)

      subject.options = { name: 'new-token' }
      subject.send('ai:tokens:create')

      expect(captured_logs).to include('Save the token value now - it will not be shown again!')
    end
  end

  describe '#ai:tokens:show' do
    let(:ai_token_resource) { double('ai_token_resource') }
    let(:token_guid) { 'sk-test-token-12345' }
    let(:token_response) do
      double('response', body: {
               'id' => token_guid,
               'name' => 'test-token',
               'created_at' => '2025-11-14T21:00:00Z',
               'updated_at' => '2025-11-14T21:00:00Z',
               'last_used_at' => nil,
               'revoked_at' => nil
             })
    end

    before do
      allow(Aptible::Api::Resource).to receive(:new)
        .with(token: token)
        .and_return(ai_token_resource)
      allow(ai_token_resource).to receive(:href=)
    end

    it 'shows an AI token successfully' do
      allow(ai_token_resource).to receive(:get).and_return(token_response)

      expect { subject.send('ai:tokens:show', token_guid) }.not_to raise_error

      expect(ai_token_resource).to have_received(:href=).with("/ai_tokens/#{token_guid}")
      expect(ai_token_resource).to have_received(:get)
      expect(captured_output_text).to include('test-token')
      expect(captured_output_text).to include(token_guid)
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

      expect { subject.send('ai:tokens:show', token_guid) }
        .to raise_error(Thor::Error, /Failed to retrieve token/)
    end
  end

  describe '#ai:tokens:revoke' do
    let(:ai_token_resource) { double('ai_token_resource') }
    let(:token_guid) { 'sk-test-token-12345' }

    before do
      allow(Aptible::Api::Resource).to receive(:new)
        .with(token: token)
        .and_return(ai_token_resource)
      allow(ai_token_resource).to receive(:href=)
    end

    it 'revokes an AI token successfully' do
      allow(ai_token_resource).to receive(:delete)

      subject.send('ai:tokens:revoke', token_guid)

      expect(ai_token_resource).to have_received(:href=).with("/ai_tokens/#{token_guid}")
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

      expect { subject.send('ai:tokens:revoke', token_guid) }
        .to raise_error(Thor::Error, /Failed to revoke token/)
    end
  end
end


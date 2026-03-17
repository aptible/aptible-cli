# frozen_string_literal: true

require 'spec_helper'
require 'net/http'
require 'json'

# Integration tests - require a running deploy-api instance
#
# Prerequisites:
#   1. Running deploy-api at DEPLOY_API_URL (e.g., http://localhost:3000)
#   2. Valid Aptible API token in DEPLOY_API_TOKEN
#   3. Target environment handle in TEST_ENVIRONMENT (e.g., "test-env")
#   4. LLM Gateway configured in deploy-api (or mocked)
#
# Run with:
#   DEPLOY_API_URL=http://localhost:3000 \
#   DEPLOY_API_TOKEN=your_token \
#   TEST_ENVIRONMENT=your-env-handle \
#   bundle exec rspec --tag integration
#
describe 'AI Tokens Integration', :integration do
  before(:all) do
    @api_url = ENV['DEPLOY_API_URL']
    @api_token = ENV['DEPLOY_API_TOKEN']
    @test_env = ENV['TEST_ENVIRONMENT']

    skip 'Set DEPLOY_API_URL to run integration tests' unless @api_url
    skip 'Set DEPLOY_API_TOKEN to run integration tests' unless @api_token
    skip 'Set TEST_ENVIRONMENT to run integration tests' unless @test_env

    # Check if API is reachable
    begin
      uri = URI.parse(@api_url)
      response = Net::HTTP.get_response(uri)
      unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
        skip "Deploy API not reachable at #{@api_url}"
      end
    rescue StandardError => e
      skip "Deploy API not reachable at #{@api_url}: #{e.message}"
    end
  end

  let(:api_url) { @api_url }
  let(:api_token) { @api_token }
  let(:test_env) { @test_env }
  let(:created_token_ids) { @created_token_ids ||= [] }

  # Clean up any tokens created during tests
  after(:all) do
    next unless @created_token_ids && @api_token

    @created_token_ids.each do |token_id|
      # Best effort cleanup - don't fail if token already deleted
      system("DEPLOY_API_URL=#{@api_url} DEPLOY_API_TOKEN=#{@api_token} " \
             "bundle exec aptible ai:tokens:revoke #{token_id} 2>/dev/null")
    rescue StandardError
      # Ignore errors during cleanup
    end
  end

  # Helper to make direct API calls for verification
  def make_api_request(method, path, body = nil)
    uri = URI.parse("#{api_url}#{path}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'

    request = case method
              when :get then Net::HTTP::Get.new(uri)
              when :post then Net::HTTP::Post.new(uri)
              when :delete then Net::HTTP::Delete.new(uri)
              end

    request['Authorization'] = "Bearer #{api_token}"
    request['Accept'] = 'application/hal+json'
    request['Content-Type'] = 'application/json' if body
    request.body = body.to_json if body

    http.request(request)
  end

  describe 'ai:tokens:list' do
    it 'successfully connects to deploy-api and lists tokens' do
      # Get accounts first to find an account ID
      response = make_api_request(:get, '/accounts')
      expect(response.code).to eq('200'), "Failed to fetch accounts: #{response.body}"

      data = JSON.parse(response.body)
      accounts = data.dig('_embedded', 'accounts')
      expect(accounts).not_to be_empty, 'No accounts found'

      account_id = accounts.first['id']

      # List tokens for this account
      response = make_api_request(:get, "/accounts/#{account_id}/ai_tokens")
      expect(response.code).to eq('200'), "Failed to list tokens: #{response.body}"

      data = JSON.parse(response.body)
      expect(data).to have_key('_embedded')
      expect(data['_embedded']).to have_key('ai_tokens')
      # The list might be empty, that's OK
      expect(data['_embedded']['ai_tokens']).to be_an(Array)
    end
  end

  describe 'ai:tokens:create' do
    it 'creates a new AI token via API' do
      # Get accounts to find an account ID
      response = make_api_request(:get, '/accounts')
      expect(response.code).to eq('200')

      data = JSON.parse(response.body)
      account_id = data.dig('_embedded', 'accounts', 0, 'id')
      expect(account_id).not_to be_nil

      # Create a token
      token_name = "integration-test-#{Time.now.to_i}"
      response = make_api_request(:post, "/accounts/#{account_id}/ai_tokens", { name: token_name })

      expect(response.code).to eq('201'), "Failed to create token: #{response.body}"

      data = JSON.parse(response.body)
      expect(data['name']).to eq(token_name)
      expect(data['id']).not_to be_nil
      expect(data['token']).not_to be_nil # Should include token value on creation
      expect(data['_type']).to eq('ai_token')

      # Track for cleanup
      @created_token_ids ||= []
      @created_token_ids << data['id']
    end
  end

  describe 'ai:tokens:show' do
    it 'retrieves details of a specific token' do
      # First create a token
      response = make_api_request(:get, '/accounts')
      account_id = JSON.parse(response.body).dig('_embedded', 'accounts', 0, 'id')

      create_response = make_api_request(:post, "/accounts/#{account_id}/ai_tokens",
                                         { name: "show-test-#{Time.now.to_i}" })
      token_data = JSON.parse(create_response.body)
      token_id = token_data['id']

      @created_token_ids ||= []
      @created_token_ids << token_id

      # Now retrieve it
      response = make_api_request(:get, "/ai_tokens/#{token_id}")
      expect(response.code).to eq('200'), "Failed to get token: #{response.body}"

      data = JSON.parse(response.body)
      expect(data['id']).to eq(token_id)
      expect(data['token']).to be_nil # Should NOT include token value on show
    end
  end

  describe 'ai:tokens:revoke' do
    it 'revokes an existing token' do
      # First create a token
      response = make_api_request(:get, '/accounts')
      account_id = JSON.parse(response.body).dig('_embedded', 'accounts', 0, 'id')

      create_response = make_api_request(:post, "/accounts/#{account_id}/ai_tokens",
                                         { name: "revoke-test-#{Time.now.to_i}" })
      token_data = JSON.parse(create_response.body)
      token_id = token_data['id']

      # Revoke it
      response = make_api_request(:delete, "/ai_tokens/#{token_id}")
      expect(response.code).to eq('204'), "Failed to revoke token: #{response.body}"

      # Verify it's gone (should return 404)
      response = make_api_request(:get, "/ai_tokens/#{token_id}")
      expect(response.code).to eq('404'), "Token should not be found after revocation"
    end
  end

  describe 'authorization' do
    it 'rejects requests without a valid token' do
      response = make_api_request(:get, '/accounts')
      account_id = JSON.parse(response.body).dig('_embedded', 'accounts', 0, 'id')

      # Try to create without proper auth by temporarily using bad token
      uri = URI.parse("#{api_url}/accounts/#{account_id}/ai_tokens")
      http = Net::HTTP.new(uri.host, uri.port)
      request = Net::HTTP::Post.new(uri)
      request['Authorization'] = 'Bearer invalid-token'
      request['Content-Type'] = 'application/json'
      request.body = { name: 'unauthorized-test' }.to_json

      response = http.request(request)
      expect(response.code).to eq('401'), 'Should reject invalid token'
    end
  end
end


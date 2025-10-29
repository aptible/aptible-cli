class StubAiToken < OpenStruct
  def attributes
    {
      'id' => id,
      'name' => name,
      'token' => token,
      'created_at' => created_at
    }
  end
end

Fabricator(:ai_token, from: :stub_ai_token) do
  id { sequence(:ai_token_id) }
  name 'test-ai-token'
  token 'sk-test-token-12345'
  created_at { Time.now }
  account
  links do |attrs|
    hash = {
      account: OpenStruct.new(
        href: "/accounts/#{attrs[:account].id}"
      )
    }
    OpenStruct.new(hash)
  end

  after_create { |ai_token| ai_token.account.ai_tokens << ai_token }
end


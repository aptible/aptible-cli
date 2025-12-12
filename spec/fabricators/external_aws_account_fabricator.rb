class StubExternalAwsAccount < OpenStruct
  def attributes
    {
      'aws_account_id' => aws_account_id,
      'account_name' => account_name,
      'aws_region_primary' => aws_region_primary,
      'status' => status,
      'discovery_enabled' => discovery_enabled,
      'discovery_frequency' => discovery_frequency,
      'role_arn' => role_arn,
      'account_id' => account_id,
      'created_at' => created_at,
      'updated_at' => updated_at
    }
  end
end

Fabricator(:external_aws_account, from: :stub_external_aws_account) do
  id { Fabricate.sequence(:external_aws_account_id) { |i| i } }
  account

  account_name { |attrs| "External AWS Account #{attrs[:id]}" }
  aws_account_id do
    Fabricate.sequence(:aws_account_id) do |i|
      format('%012d', 10_000_000_000 + i)
    end
  end
  role_arn { |attrs| "arn:aws:iam::#{attrs[:aws_account_id]}:role/ExampleRole" }
  aws_region_primary 'us-east-1'
  status 'active'
  discovery_enabled false
  discovery_frequency 'daily'
  account_id { |attrs| attrs[:account] ? attrs[:account].id : nil }
  created_at { Time.now }
  updated_at { Time.now }

  links do |attrs|
    hash = {}
    if attrs[:account]
      hash[:account] = OpenStruct.new(
        href: "/accounts/#{attrs[:account].id}"
      )
    end
    OpenStruct.new(hash)
  end
end

class StubExternalAwsResource < OpenStruct
  def attributes
    {
      'id' => id,
      'external_aws_account_id' => external_aws_account_id,
      'resource_type' => resource_type,
      'resource_arn' => resource_arn,
      'resource_id' => resource_id,
      'resource_name' => resource_name,
      'region' => region,
      'metadata' => metadata,
      'tags' => tags,
      'discovered_at' => discovered_at,
      'last_synced_at' => last_synced_at,
      'sync_status' => sync_status,
      'created_at' => created_at,
      'updated_at' => updated_at
    }
  end
end

Fabricator(:external_aws_resource, from: :stub_external_aws_resource) do
  id { Fabricate.sequence(:external_aws_resource_id) { |i| i } }
  external_aws_account

  resource_type { 'aws_rds_db_instance' }
  resource_arn do
    Fabricate.sequence(:external_aws_resource_arn) do |i|
      "arn:aws:rds:us-east-1:123456789012:db:example-db-#{i}"
    end
  end
  resource_id do
    Fabricate.sequence(:external_aws_resource_resource_id) do |i|
      "db-EXAMPLE#{i}"
    end
  end
  resource_name do
    Fabricate.sequence(:external_aws_resource_name) { |i| "example-db-#{i}" }
  end
  region { 'us-east-1' }

  metadata { { 'engine' => 'postgres', 'engine_version' => '14.7' } }
  tags { { 'env' => 'test', 'owner' => 'spec' } }

  discovered_at { Time.now }
  last_synced_at { Time.now }
  sync_status { 'current' }
  created_at { Time.now }
  updated_at { Time.now }

  external_aws_account_id do |attrs|
    attrs[:external_aws_account] ? attrs[:external_aws_account].id : nil
  end

  links do |attrs|
    hash = {}
    if attrs[:external_aws_account]
      hash[:external_aws_account] = OpenStruct.new(
        href: "/external_aws_accounts/#{attrs[:external_aws_account].id}"
      )
    end
    OpenStruct.new(hash)
  end
end

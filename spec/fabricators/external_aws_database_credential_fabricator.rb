class StubExternalAwsDatabaseCredential < OpenStruct
  def attributes
    {
      'id' => id,
      'external_aws_resource_id' => external_aws_resource_id,
      'type' => type,
      'default' => default,
      'connection_url' => connection_url,
      'created_at' => created_at,
      'updated_at' => updated_at
    }
  end
end

Fabricator(:external_aws_database_credential,
           from: :stub_external_aws_database_credential) do
  id do
    Fabricate.sequence(:external_aws_database_credential_id) { |i| i }
  end
  external_aws_resource do
    Fabricate(:external_aws_resource, resource_type: 'aws_rds_db_instance')
  end

  type do
    Fabricate.sequence(:external_aws_db_cred_type) { |i| "primary-#{i}" }
  end
  default { false }
  connection_url { 'postgres://user:pass@host:5432/dbname' }

  created_at { Time.now }
  updated_at { Time.now }

  external_aws_resource_id do |attrs|
    attrs[:external_aws_resource] ? attrs[:external_aws_resource].id : nil
  end

  links do |attrs|
    hash = {}
    if attrs[:external_aws_resource]
      hash[:external_aws_resource] = OpenStruct.new(
        href: "/external_aws_resources/#{attrs[:external_aws_resource].id}"
      )
    end
    OpenStruct.new(hash)
  end
end

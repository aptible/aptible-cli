class StubAppExternalAwsRdsConnection < OpenStruct
  def attributes
    {
      'id' => id,
      'app_id' => app_id,
      'external_aws_resource_id' => external_aws_resource_id,
      'database_name' => database_name,
      'database_user' => database_user,
      'superuser' => superuser,
      'created_at' => created_at,
      'updated_at' => updated_at
    }
  end
end

Fabricator(:app_external_aws_rds_connection,
           from: :stub_app_external_aws_rds_connection) do
  id do
    Fabricate.sequence(:app_external_aws_rds_connection_id) { |i| i }
  end
  app
  external_aws_resource do
    Fabricate(:external_aws_resource, resource_type: 'aws_rds_db_instance')
  end

  database_name { Fabricate.sequence(:db_name) { |i| "db_#{i}" } }
  database_user { Fabricate.sequence(:db_user) { |i| "user_#{i}" } }
  superuser { false }

  created_at { Time.now }
  updated_at { Time.now }

  app_id do |attrs|
    attrs[:app] ? attrs[:app].id : nil
  end

  external_aws_resource_id do |attrs|
    attrs[:external_aws_resource] ? attrs[:external_aws_resource].id : nil
  end

  links do |attrs|
    hash = {}
    if attrs[:app]
      hash[:app] = OpenStruct.new(
        href: "/apps/#{attrs[:app].id}"
      )
    end
    if attrs[:external_aws_resource]
      hash[:external_aws_resource] = OpenStruct.new(
        href: "/external_aws_resources/#{attrs[:external_aws_resource].id}"
      )
    end
    OpenStruct.new(hash)
  end
end

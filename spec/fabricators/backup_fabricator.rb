class StubBackup < OpenStruct; end

Fabricator(:backup, from: :stub_backup) do
  id { sequence(:backup_id) }
  aws_region { %w(us-east-1 us-west-1).sample }
  created_at { Time.now }
  database

  after_create { |backup| backup.database.backups << backup }
end

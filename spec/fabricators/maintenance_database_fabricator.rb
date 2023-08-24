class StubMaintenanceDatabase < OpenStruct; end

Fabricator(:maintenance_database, from: :stub_maintenance_database) do
  id { Fabricate.sequence(:database_id) { |i| i } }
  handle 'hello'
  status 'provisioned'
  account
  created_at { Time.now }
  maintenance_deadline { [Time.now + 1.minute, Time.now + 2.minute] }
end

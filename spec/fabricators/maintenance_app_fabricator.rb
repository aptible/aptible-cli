class StubMaintenanceApp < OpenStruct; end

Fabricator(:maintenance_app, from: :stub_maintenance_app) do
  id { Fabricate.sequence(:app_id) { |i| i } }
  handle 'hello'
  status 'provisioned'
  account
  created_at { Time.now }
  maintenance_deadline { [Time.now + 1.minute, Time.now + 2.minute] }
end

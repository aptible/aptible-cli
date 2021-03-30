class StubOperation < OpenStruct; end

Fabricator(:operation, from: :stub_operation) do
  status 'queued'
  created_at { Time.now - 1.minute }
  updated_at { Time.now }
  resource { Fabricate(:app) }
  errors { Aptible::Resource::Errors.new }
end

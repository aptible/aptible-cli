class StubOperation < OpenStruct; end

def mock_logs_url(id)
  "https://api.aptible.com/operations/#{id}/logs"
end

Fabricator(:operation, from: :stub_operation) do
  status 'queued'
  errors { Aptible::Resource::Errors.new }
  resource { Fabricate(:app) }
  after_save { |operation| operation.logs_url = mock_logs_url(operation.id) }
end

class StubOperation < OpenStruct; end

Fabricator(:operation, from: :stub_operation) do
  status 'queued'
  resource { Fabricate(:app) }
end

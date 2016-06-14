class StubService < OpenStruct; end

Fabricator(:service, from: :stub_service) do
  process_type 'web'
  app
  vhosts { [] }

  after_create { |service| service.app.services << service }
end

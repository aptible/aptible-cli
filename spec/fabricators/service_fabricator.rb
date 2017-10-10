class StubService < OpenStruct
  def each_vhost(&block)
    return enum_for(:each_vhost) if block.nil?
    vhosts.each(&block)
  end
end

Fabricator(:service, from: :stub_service) do
  transient :app, :database

  process_type 'web'
  vhosts { [] }

  after_create do |service, transients|
    if transients[:app]
      service.app = transients[:app]
    elsif transients[:database]
      service.database = transients[:database]
    else
      service.app = Fabricate(:app)
    end

    if service.app
      service.app.services << service
      service.account = service.app.account
    else
      service.database.service = service
      service.account = service.database.account
    end
  end
end

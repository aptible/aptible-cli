class StubApp < OpenStruct
  def vhosts
    services.map(&:vhosts).flatten
  end

  def each_vhost(&block)
    return enum_for(:each_vhost) if block.nil?
    vhosts.each(&block)
  end

  def each_service(&block)
    return enum_for(:each_service) if block.nil?
    services.each(&block)
  end

  def each_configuration(&block)
    return enum_for(:each_configuration) if block.nil?
    configurations.each(&block)
  end
end

Fabricator(:app, from: :stub_app) do
  id { Fabricate.sequence(:app_id) { |i| i } }
  handle 'hello'
  status 'provisioned'
  git_repo { Fabricate.sequence(:app_git_repo) { |i| "git://#{i}.git" } }
  account
  services { [] }
  configurations { [] }
  current_configuration { nil }
  errors { Aptible::Resource::Errors.new }

  after_create { |app| app.account.apps << app }
end

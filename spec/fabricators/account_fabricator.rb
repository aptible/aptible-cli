class StubAccount < OpenStruct
  def each_app(&block)
    return enum_for(:each_app) if block.nil?
    apps.each(&block)
  end

  def each_database(&block)
    return enum_for(:each_database) if block.nil?
    databases.each(&block)
  end

  def each_certificate(&block)
    return enum_for(:each_certificate) if block.nil?
    certificates.each(&block)
  end
end

Fabricator(:account, from: :stub_account) do
  id { Fabricate.sequence(:account_id) { |i| i } }
  bastion_host 'localhost'
  dumptruck_port 1234
  handle 'aptible'
  ca_body '--BEGIN FAKE CERT-- test --END FAKE CERT--'
  stack

  apps { [] }
  databases { [] }
  certificates { [] }
  log_drains { [] }
  metric_drains { [] }
  created_at { Time.now }
end

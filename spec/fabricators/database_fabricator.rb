class StubDatabase < OpenStruct
  def provisioned?
    status == 'provisioned'
  end
end

Fabricator(:database, from: :stub_database) do
  type 'postgresql'
  handle do |attrs|
    Fabricate.sequence(:database) { |i| "#{attrs[:type]}-#{i}" }
  end
  passphrase 'password'
  status 'provisioned'
  connection_url 'postgresql://aptible:password@10.252.1.125:49158/db'
  account

  backups { [] }
  database_credentials { [] }

  after_create { |database| database.account.databases << database }
end

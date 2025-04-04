class StubDatabase < OpenStruct
  def provisioned?
    status == 'provisioned'
  end
end

Fabricator(:database, from: :stub_database) do
  transient :service

  type 'postgresql'
  handle do |attrs|
    Fabricate.sequence(:database) { |i| "#{attrs[:type]}-#{i}" }
  end

  passphrase 'password'
  status 'provisioned'
  connection_url 'postgresql://aptible:password@10.252.1.125:49158/db'
  account
  database_image
  disk { Fabricate(:database_disk) }
  service { nil }
  links do |attrs|
    hash = {
      account: OpenStruct.new(
        href: "/accounts/#{attrs[:account].id}"
      )
    }
    OpenStruct.new(hash)
  end

  backups { [] }
  database_credentials { [] }
  created_at { Time.now }

  after_create do |database, transients|
    database.account.databases << database
    unless status == 'provisioning'
      database.service = transients[:service] || Fabricate(
        :service, app: nil, database: database
      )
    end
  end
end

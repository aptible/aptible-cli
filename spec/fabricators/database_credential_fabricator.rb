class StubDatabaseCredential < OpenStruct; end

Fabricator(:database_credential, from: :stub_database_credential) do
  database

  default false
  type 'postgresql'
  connection_url 'postgresql://aptible:password@10.252.1.125:49158/db'

  after_create { |credential| database.database_credentials << credential }
end

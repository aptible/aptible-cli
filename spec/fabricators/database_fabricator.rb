class StubDatabase < OpenStruct; end

Fabricator(:database, from: :stub_database) do
  type 'postgresql'
  handle do |attrs|
    Fabricate.sequence(:database) { |i| "#{attrs[:type]}-#{i}" }
  end
  passphrase 'password'
  connection_url 'postgresql://aptible:password@10.252.1.125:49158/db'
  account

  after_create { |database| database.account.databases << database }
end

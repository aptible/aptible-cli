class StubCertificate < OpenStruct; end

Fabricator(:certificate, from: :stub_certificate) do
  account

  sha256_fingerprint do
    Fabricate.sequence(:sha256) { |i| Digest::SHA256.hexdigest(i.to_s) }
  end

  after_create { |cert| cert.account.certificates << cert }
end

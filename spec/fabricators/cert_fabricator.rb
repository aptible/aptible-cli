class StubCert < OpenStruct; end

Fabricator(:cert, from: :stub_cert) do
  common_name '*.example.com'
  issuer_organization 'Justice League'
  not_before '2015-08-20T00:00:00.000Z'
  not_after '2017-08-20T00:00:00.000Z'
  id { rand(10000) }
end

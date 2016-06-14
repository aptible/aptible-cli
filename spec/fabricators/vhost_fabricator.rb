class StubVhost < OpenStruct; end

Fabricator(:vhost, from: :stub_vhost) do
  virtual_domain 'domain1'
  external_host 'host1'
  service

  after_create { |vhost| vhost.service.vhosts << vhost }
end

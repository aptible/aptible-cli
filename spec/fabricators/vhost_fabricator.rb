class StubVhost < OpenStruct; end

Fabricator(:vhost, from: :stub_vhost) do
  service

  external_host { Fabricate.sequence(:external_host) { |i| "host#{i}" } }
  virtual_domain { Fabricate.sequence(:virtual_domain) { |i| "domain#{i}" } }
  ip_whitelist { [] }
  container_ports { [] }

  after_create { |vhost| vhost.service.vhosts << vhost }
end

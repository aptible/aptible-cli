require 'spec_helper'

describe Aptible::CLI::ResourceFormatter do
  def capture(m, *args)
    node = Aptible::CLI::Formatter::Object.new
    described_class.public_send(m, node, *args)
    Aptible::CLI::Renderer::Text.new.render(node).split("\n")
  end

  describe '#inject_vhost' do
    it 'explains a VHOST' do
      service = Fabricate(:service, process_type: 'web')
      vhost = Fabricate(
        :vhost,
        id: 12,
        service: service,
        external_host: 'foo.io',
        status: 'provisioned',
        type: 'http_proxy_protocol',
        internal: false,
        ip_whitelist: [],
        default: false,
        acme: false
      )

      expected = [
        'Id: 12',
        'Hostname: foo.io',
        'Status: provisioned',
        'Type: https',
        'Port: default',
        'Internal: false',
        'IP Whitelist: all traffic',
        'Default Domain Enabled: false',
        'Managed TLS Enabled: false',
        'Service: web'
      ]
      expect(capture(:inject_vhost, vhost, service)).to eq(expected)
    end

    it 'explains a failed VHOST' do
      vhost = Fabricate(:vhost, status: 'provision_failed')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Status: provision_failed')
    end

    it 'explains an internal VHOST' do
      vhost = Fabricate(:vhost, internal: true)
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Internal: true')
    end

    it 'explains a default VHOST' do
      vhost = Fabricate(:vhost, default: true, virtual_domain: 'qux.io')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Default Domain Enabled: true')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Default Domain: qux.io')
    end

    it 'explains a TLS VHOST' do
      vhost = Fabricate(:vhost, type: 'tls')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Type: tls')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Ports: all')
    end

    it 'explains a TCP VHOST' do
      vhost = Fabricate(:vhost, type: 'tcp')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Type: tcp')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Ports: all')
    end

    it 'explains a VHOST with a container port' do
      vhost = Fabricate(:vhost, type: 'http_proxy_protocol', container_port: 12)
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Port: 12')
    end

    it 'explains a VHOST with container ports' do
      vhost = Fabricate(:vhost, type: 'tls', container_ports: [12, 34])
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Ports: 12 34')
    end

    it 'explains a VHOST with IP Filtering' do
      vhost = Fabricate(:vhost, ip_whitelist: %w(1.1.1.1/1 2.2.2.2/2))
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('IP Whitelist: 1.1.1.1/1 2.2.2.2/2')
    end

    it 'explains a VHOST with Managed TLS' do
      vhost = Fabricate(
        :vhost,
        acme: true,
        user_domain: 'foo.io',
        acme_dns_challenge_host: 'dns.qux.io',
        acme_status: 'ready'
      )
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Managed TLS Enabled: true')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Managed TLS Domain: foo.io')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Managed TLS DNS Challenge Hostname: dns.qux.io')
      expect(capture(:inject_vhost, vhost, vhost.service))
        .to include('Managed TLS Status: ready')
    end
  end
end

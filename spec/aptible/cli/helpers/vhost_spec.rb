require 'spec_helper'

describe Aptible::CLI::Helpers::Vhost do
  subject { Class.new.send(:include, described_class).new }

  describe '#explain_vhost' do
    let(:lines) { [] }
    before { allow(subject).to receive(:say) { |m| lines << m } }

    it 'explains a VHOST' do
      service = Fabricate(:service, process_type: 'web')
      vhost = Fabricate(
        :vhost,
        service: service,
        external_host: 'foo.io',
        status: 'provisioned',
        type: 'http_proxy_protocol',
        internal: false,
        ip_whitelist: [],
        default: false,
        acme: false
      )
      subject.explain_vhost(service, vhost)

      expected = [
        'Service: web',
        'Hostname: foo.io',
        'Status: provisioned',
        'Type: https',
        'Port: default',
        'Internal: false',
        'IP Whitelist: all traffic',
        'Default Domain Enabled: false',
        'Managed TLS Enabled: false'
      ]
      expect(lines).to eq(expected)
    end

    it 'explains a failed VHOST' do
      vhost = Fabricate(:vhost, status: 'provision_failed')
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Status: provision_failed')
    end

    it 'explains an internal VHOST' do
      vhost = Fabricate(:vhost, internal: true)
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Internal: true')
    end

    it 'explains a default VHOST' do
      vhost = Fabricate(:vhost, default: true, virtual_domain: 'qux.io')
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Default Domain Enabled: true')
      expect(lines).to include('Default Domain: qux.io')
    end

    it 'explains a TLS VHOST' do
      vhost = Fabricate(:vhost, type: 'tls')
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Type: tls')
      expect(lines).to include('Ports: all')
    end

    it 'explains a TCP VHOST' do
      vhost = Fabricate(:vhost, type: 'tcp')
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Type: tcp')
      expect(lines).to include('Ports: all')
    end

    it 'explains a VHOST with a container port' do
      vhost = Fabricate(:vhost, type: 'http_proxy_protocol', container_port: 12)
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Port: 12')
    end

    it 'explains a VHOST with container ports' do
      vhost = Fabricate(:vhost, type: 'tls', container_ports: [12, 34])
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Ports: 12 34')
    end

    it 'explains a VHOST with IP Filtering' do
      vhost = Fabricate(:vhost, ip_whitelist: %w(1.1.1.1/1 2.2.2.2/2))
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('IP Whitelist: 1.1.1.1/1 2.2.2.2/2')
    end

    it 'explains a VHOST with Managed TLS' do
      vhost = Fabricate(
        :vhost,
        acme: true,
        user_domain: 'foo.io',
        acme_dns_challenge_host: 'dns.qux.io',
        acme_status: 'ready'
      )
      subject.explain_vhost(vhost.service, vhost)
      expect(lines).to include('Managed TLS Enabled: true')
      expect(lines).to include('Managed TLS Domain: foo.io')
      expect(lines).to include('Managed TLS DNS Challenge Hostname: dns.qux.io')
      expect(lines).to include('Managed TLS Status: ready')
    end
  end
end

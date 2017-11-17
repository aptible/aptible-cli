require 'spec_helper'

describe Aptible::CLI::Agent do
  let!(:a1) { Fabricate(:account, handle: 'foo') }
  let!(:a2) { Fabricate(:account, handle: 'bar') }

  let(:token) { double 'token' }

  before do
    allow(subject).to receive(:fetch_token) { token }
    allow(Aptible::Api::Account).to receive(:all).with(token: token)
      .and_return([a1, a2])
  end

  def expect_create_certificate(account, options)
    expect(account).to receive(:create_certificate!).with(
      hash_including(options)
    ) do |args|
      Fabricate(:certificate, account: account, **args)
    end
  end

  def expect_create_vhost(service, options)
    expect(service).to receive(:create_vhost!).with(
      hash_including(options)
    ) do |args|
      Fabricate(:vhost, service: service, **args).tap do |v|
        expect_operation(v, 'provision')
        expect(v).to receive(:reload).and_return(v)
        expect(Aptible::CLI::ResourceFormatter).to receive(:inject_vhost)
          .with(an_instance_of(Aptible::CLI::Formatter::Object), v, service)
      end
    end
  end

  def expect_modify_vhost(vhost, options)
    expect(vhost).to receive(:update!).with(options) do
      expect_operation(vhost, 'provision')
      expect(vhost).to receive(:reload).and_return(vhost)
      expect(Aptible::CLI::ResourceFormatter).to receive(:inject_vhost)
        .with(
          an_instance_of(Aptible::CLI::Formatter::Object), vhost, vhost.service
        )
    end
  end

  def expect_operation(vhost, type)
    expect(vhost).to receive(:create_operation!).with(type: type) do
      Fabricate(:operation).tap do |o|
        expect(subject).to receive(:attach_to_operation_logs).with(o)
      end
    end
  end

  context 'Database Endpoints' do
    def stub_options(**opts)
      allow(subject).to receive(:options).and_return(opts)
    end

    let!(:db) { Fabricate(:database, handle: 'mydb', account: a1) }

    before do
      allow(Aptible::Api::Database).to receive(:all).with(token: token)
        .and_return([db])
      allow(db).to receive(:class).and_return(Aptible::Api::Database)
      stub_options
    end

    describe 'endpoints:database:create' do
      it 'fails if the DB does not exist' do
        expect { subject.send('endpoints:database:create', 'some') }
          .to raise_error(/could not find database some/im)
      end

      it 'fails if the DB is not in the account' do
        stub_options(environment: 'bar')
        expect { subject.send('endpoints:database:create', 'mydb') }
          .to raise_error(/could not find database mydb/im)
      end

      it 'creates a new Endpoint' do
        expect_create_vhost(
          db.service,
          type: 'tcp',
          platform: 'elb',
          internal: false,
          ip_whitelist: []
        )
        subject.send('endpoints:database:create', 'mydb')
      end

      it 'creates a new Endpoint with IP Filtering' do
        expect_create_vhost(db.service, ip_whitelist: %w(1.1.1.1))
        stub_options(ip_whitelist: %w(1.1.1.1))
        subject.send('endpoints:database:create', 'mydb')
      end
    end

    describe 'endpoints:list' do
      it 'lists Endpoints' do
        s = Fabricate(:service, database: db)
        v1 = Fabricate(:vhost, service: s)
        v2 = Fabricate(:vhost, service: s)

        stub_options(database: db.handle)
        subject.send('endpoints:list')

        lines = captured_output_text.split("\n")

        expect(lines).to include("Hostname: #{v1.external_host}")
        expect(lines).to include("Hostname: #{v2.external_host}")

        expect(lines[0]).not_to eq("\n")
        expect(lines[-1]).not_to eq("\n")
      end
    end

    describe 'endpoints:deprovison' do
      it 'deprovisions an Endpoint' do
        s = Fabricate(:service, database: db)
        Fabricate(:vhost, service: s)
        v2 = Fabricate(:vhost, service: s)

        stub_options(database: db.handle)

        expect_operation(v2, 'deprovision')
        subject.send('endpoints:deprovision', v2.external_host)
      end

      it 'fails if the Endpoint does not exist' do
        stub_options(database: db.handle)

        expect { subject.send('endpoints:deprovision', 'foo.io') }
          .to raise_error(/endpoint.*foo\.io.*does not exist/im)
      end
    end
  end

  context 'App Endpoints' do
    def stub_options(**opts)
      base = { app: app.handle }
      allow(subject).to receive(:options).and_return(base.merge(opts))
    end

    let!(:app) { Fabricate(:app, handle: 'myapp', account: a1) }
    let!(:service) { Fabricate(:service, app: app, process_type: 'web') }

    before do
      allow(Aptible::Api::App).to receive(:all).with(token: token)
        .and_return([app])
      allow(app).to receive(:class).and_return(Aptible::Api::App)
      stub_options
    end

    shared_examples 'shared create app vhost examples' do |method|
      context 'App Vhost Options' do
        it 'fails if the app does not exist' do
          stub_options(app: 'foo')
          expect { subject.send(method, 'foo') }
            .to raise_error(/could not find app/im)
        end

        it 'fails if the service does not exist' do
          expect { subject.send(method, 'foo') }
            .to raise_error(/service.*does not exist/im)
        end

        it 'creates an internal Endpoint' do
          expect_create_vhost(service, internal: true)
          stub_options(internal: true)
          subject.send(method, 'web')
        end

        it 'creates an Endpoint with IP Filtering' do
          expect_create_vhost(service, ip_whitelist: %w(1.1.1.1))
          stub_options(ip_whitelist: %w(1.1.1.1))
          subject.send(method, 'web')
        end

        it 'creates a default Endpoint' do
          expect_create_vhost(service, default: true)
          stub_options(default_domain: true)
          subject.send(method, 'web')
        end
      end
    end

    shared_examples 'shared create tcp vhost examples' do |method|
      context 'TCP VHOST Options' do
        it 'creates an Endpoint with Ports' do
          expect_create_vhost(service, container_ports: [10, 20])
          stub_options(ports: %w(10 20))
          subject.send(method, 'web')
        end

        it 'raises an error if the ports are invalid' do
          stub_options(ports: %w(foo))
          expect { subject.send(method, 'web') }
            .to raise_error(/invalid port: foo/im)
        end
      end
    end

    shared_examples 'shared create tls vhost examples' do |method|
      context 'TLS Vhost Options' do
        it 'creates an Endpoint with a new Certificate' do
          expect_create_certificate(
            a1,
            certificate_body: 'the cert',
            private_key: 'the key'
          )

          expect_create_vhost(
            service,
            certificate: an_instance_of(StubCertificate),
            acme: false,
            default: false
          )

          Dir.mktmpdir do |d|
            cert, key = %w(cert key).map { |f| File.join(d, f) }
            File.write(cert, 'the cert')
            File.write(key, 'the key')
            stub_options(certificate_file: cert, private_key_file: key)
            subject.send(method, 'web')
          end
        end

        it 'fails if certificate file is not provided' do
          stub_options(private_key_file: 'foo')
          expect { subject.send(method, 'web') }
            .to raise_error(/missing --certificate-file/im)
        end

        it 'fails if private key file is not provided' do
          stub_options(certificate_file: 'foo')
          expect { subject.send(method, 'web') }
            .to raise_error(/missing --private-key-file/im)
        end

        it 'fails if a file is unreadable' do
          Dir.mktmpdir do |d|
            cert, key = %w(cert key).map { |f| File.join(d, f) }
            stub_options(certificate_file: cert, private_key_file: key)
            expect { subject.send(method, 'web') }
              .to raise_error(/failed to read certificate or private key/im)
          end
        end

        it 'creates an Endpoint with an existing Certificate (exact match)' do
          c = Fabricate(:certificate, account: a1)
          stub_options(certificate_fingerprint: c.sha256_fingerprint)

          expect_create_vhost(
            service,
            certificate: c,
            acme: false,
            default: false
          )

          subject.send(method, 'web')
        end

        it 'creates an Endpoint with an existing Certificate (one match)' do
          c = Fabricate(:certificate, account: a1)
          Fabricate(:certificate, account: a1)

          stub_options(certificate_fingerprint: c.sha256_fingerprint[0..5])
          expect_create_vhost(service, certificate: c)
          subject.send(method, 'web')
        end

        it 'creates an Endpoint with an existing Certificate (dupe matches)' do
          c1 = Fabricate(:certificate, account: a1)
          Fabricate(
            :certificate,
            account: a1,
            sha256_fingerprint: c1.sha256_fingerprint
          )

          stub_options(certificate_fingerprint: c1.sha256_fingerprint[0..5])
          expect_create_vhost(service, certificate: c1)
          subject.send(method, 'web')
        end

        it 'creates an Endpoint with Managed TLS' do
          expect_create_vhost(
            service,
            acme: true,
            user_domain: 'foo.io'
          )

          stub_options(managed_tls: true, managed_tls_domain: 'foo.io')
          subject.send(method, 'web')
        end

        it 'requires a domain for Managed TLS' do
          stub_options(managed_tls: true)
          expect { subject.send(method, 'web') }
            .to raise_error(/--managed-tls-domain/im)
        end

        it 'fails if the certificate does not exist' do
          Fabricate(:certificate, account: a1)
          c2 = Fabricate(:certificate, account: a2)

          stub_options(certificate_fingerprint: c2.sha256_fingerprint)
          expect { subject.send(method, 'web') }
            .to raise_error(/no certificate matches fingerprint/im)
        end

        it 'fails if too many certificates match' do
          Fabricate(:certificate, account: a1, sha256_fingerprint: 'fooA')
          Fabricate(:certificate, account: a1, sha256_fingerprint: 'fooB')
          stub_options(certificate_fingerprint: 'foo')
          expect { subject.send(method, 'web') }
            .to raise_error(/too many certificates match fingerprint/im)
        end

        it 'fails if conflicting options are given (ACME, Cert)' do
          stub_options(certificate_file: 'foo', managed_tls: true)
          expect { subject.send(method, 'web') }
            .to raise_error(/conflicting options.*file.*managed/im)
        end

        it 'fails if conflicting options are given (ACME Domain, Cert)' do
          stub_options(certificate_file: 'foo', managed_tls_domain: 'bar')
          expect { subject.send(method, 'web') }
            .to raise_error(/conflicting options.*file.*managed/im)
        end

        it 'fails if conflicting options are given (ACME, Fingerprint)' do
          stub_options(certificate_fingerprint: 'foo', managed_tls: true)
          expect { subject.send(method, 'web') }
            .to raise_error(/conflicting options.*finger.*managed/im)
        end

        it 'fails if conflicting options are given (Cert, Fingerprint)' do
          stub_options(certificate_file: 'foo', certificate_fingerprint: 'foo')
          expect { subject.send(method, 'web') }
            .to raise_error(/conflicting options.*file.*finger/im)
        end

        it 'fails if conflicting options are given (ACME, Default)' do
          stub_options(managed_tls: true, default_domain: true)
          expect { subject.send(method, 'web') }
            .to raise_error(/conflicting options.*managed.*default/im)
        end
      end
    end

    describe 'endpoints:tcp:create' do
      m = 'endpoints:tcp:create'
      include_examples 'shared create app vhost examples', m
      include_examples 'shared create tcp vhost examples', m

      it 'creates a TCP Endpoint' do
        expect_create_vhost(
          service,
          type: 'tcp',
          platform: 'elb',
          internal: false,
          default: false,
          ip_whitelist: [],
          container_ports: []
        )

        subject.send(m, 'web')
      end
    end

    describe 'endpoints:tls:create' do
      m = 'endpoints:tls:create'
      include_examples 'shared create app vhost examples', m
      include_examples 'shared create tcp vhost examples', m
      include_examples 'shared create tls vhost examples', m

      it 'creates a TLS Endpoint' do
        expect_create_vhost(
          service,
          type: 'tls',
          platform: 'elb',
          internal: false,
          default: false,
          ip_whitelist: [],
          container_ports: []
        )
        subject.send(m, 'web')
      end
    end

    describe 'endpoints:https:create' do
      m = 'endpoints:https:create'
      include_examples 'shared create app vhost examples', m
      include_examples 'shared create tls vhost examples', m

      it 'creates a HTTP Endpoint' do
        expect_create_vhost(
          service,
          type: 'http',
          platform: 'alb',
          internal: false,
          default: false,
          ip_whitelist: []
        )
        subject.send(m, 'web')
      end

      it 'creates an Endpoint with a container Port' do
        expect_create_vhost(service, container_port: 10)
        stub_options(port: 10)
        subject.send(m, 'web')
      end
    end

    shared_examples 'shared modify app vhost examples' do |m|
      it 'does not change anything if no options are passed' do
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, {})
        subject.send(m, v.external_host)
      end

      it 'adds an IP whitelist' do
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, ip_whitelist: %w(1.1.1.1))

        stub_options(ip_whitelist: %w(1.1.1.1))
        subject.send(m, v.external_host)
      end

      it 'removes an IP whitelist' do
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, ip_whitelist: [])

        stub_options(:'no-ip_whitelist' => true)
        subject.send(m, v.external_host)
      end

      it 'does not allow disabling and adding an IP whitelist' do
        v = Fabricate(:vhost, service: service)
        stub_options(ip_whitelist: %w(1.1.1.1), :'no-ip_whitelist' => true)
        expect { subject.send(m, v.external_host) }
          .to raise_error(/conflicting.*no-ip-whitelist.*ip-whitelist/im)
      end
    end

    shared_examples 'shared modify tcp vhost examples' do |m|
      it 'allows updating Container Ports' do
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, container_ports: [10, 20])

        stub_options(ports: %w(10 20))
        subject.send(m, v.external_host)
      end
    end

    shared_examples 'shared modify tls vhost examples' do |m|
      it 'allows enabling Managed TLS' do
        # NOTE: As-is, this will typically fail in the backend since the
        # Managed TLS Hostname is required as well.
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, acme: true)

        stub_options(managed_tls: true)
        subject.send(m, v.external_host)
      end

      it 'allows disabling Managed TLS' do
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, acme: false)

        stub_options(managed_tls: false)
        subject.send(m, v.external_host)
      end

      it 'allows updating the Managed TLS Domain' do
        # NOTE: This will usually fail in the backend due to API validations on
        # the cert / domain matching.
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, user_domain: 'foobar.io')

        stub_options(managed_tls_domain: 'foobar.io')
        subject.send(m, v.external_host)
      end

      it 'updates the Endpoint with a new Certificate' do
        v = Fabricate(:vhost, service: service)

        expect_create_certificate(
          a1, certificate_body: 'the cert', private_key: 'the key'
        )

        expect_modify_vhost(v, certificate: an_instance_of(StubCertificate))

        Dir.mktmpdir do |d|
          cert, key = %w(cert key).map { |f| File.join(d, f) }
          File.write(cert, 'the cert')
          File.write(key, 'the key')
          stub_options(certificate_file: cert, private_key_file: key)

          subject.send(m, v.external_host)
        end
      end

      it 'updates an Endpoint with an existing Certificate (exact match)' do
        v = Fabricate(:vhost, service: service)
        c = Fabricate(:certificate, account: a1)
        stub_options(certificate_fingerprint: c.sha256_fingerprint)

        expect_modify_vhost(v, certificate: c)

        subject.send(m, v.external_host)
      end
    end

    describe 'endpoints:tcp:modify' do
      m = 'endpoints:tcp:modify'
      include_examples 'shared modify app vhost examples', m
      include_examples 'shared modify tcp vhost examples', m
    end

    describe 'endpoints:tls:modify' do
      m = 'endpoints:tls:modify'
      include_examples 'shared modify app vhost examples', m
      include_examples 'shared modify tcp vhost examples', m
      include_examples 'shared modify tls vhost examples', m
    end

    describe 'endpoints:https:modify' do
      m = 'endpoints:https:modify'
      include_examples 'shared modify app vhost examples', m
      include_examples 'shared modify tls vhost examples', m

      it 'allows updating the Container Port' do
        v = Fabricate(:vhost, service: service)
        expect_modify_vhost(v, container_port: 10)

        stub_options(port: 10)
        subject.send(m, v.external_host)
      end
    end

    describe 'endpoints:list' do
      it 'lists Endpoints across services' do
        s1 = Fabricate(:service, app: app)
        v1 = Fabricate(:vhost, service: s1)

        s2 = Fabricate(:service, app: app)
        v2 = Fabricate(:vhost, service: s2)
        v3 = Fabricate(:vhost, service: s2)

        subject.send('endpoints:list')

        lines = captured_output_text.split("\n")

        expect(lines).to include("Hostname: #{v1.external_host}")
        expect(lines).to include("Hostname: #{v2.external_host}")
        expect(lines).to include("Hostname: #{v3.external_host}")

        expect(lines[0]).not_to eq("\n")
        expect(lines[-1]).not_to eq("\n")
      end
    end

    describe 'endpoints:deprovison' do
      it 'deprovisions an Endpoint' do
        s1 = Fabricate(:service, app: app)
        Fabricate(:vhost, service: s1)

        s2 = Fabricate(:service, app: app)
        v2 = Fabricate(:vhost, service: s2)
        Fabricate(:vhost, service: s2)

        expect_operation(v2, 'deprovision')
        subject.send('endpoints:deprovision', v2.external_host)
      end

      it 'fails if the Endpoint does not exist' do
        s1 = Fabricate(:service, app: app)
        Fabricate(:vhost, service: s1, external_host: 'qux.io')

        expect { subject.send('endpoints:deprovision', 'foo.io') }
          .to raise_error(/endpoint.*foo\.io.*does not exist.*qux\.io/im)
      end
    end

    describe 'endpoints:renew' do
      it 'renews an Endpoint' do
        s1 = Fabricate(:service, app: app)
        Fabricate(:vhost, service: s1)

        s2 = Fabricate(:service, app: app)
        v2 = Fabricate(:vhost, service: s2)
        Fabricate(:vhost, service: s2)

        expect_operation(v2, 'renew')
        subject.send('endpoints:renew', v2.external_host)
      end

      it 'fails if the Endpoint does not exist' do
        expect { subject.send('endpoints:deprovision', 'foo.io') }
          .to raise_error(/endpoint.*foo\.io.*does not exist/im)
      end
    end
  end
end

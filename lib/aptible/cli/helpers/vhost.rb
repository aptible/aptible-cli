module Aptible
  module CLI
    module Helpers
      module Vhost
        def explain_vhost(service, vhost)
          say "Service: #{service.process_type}"
          say "Hostname: #{vhost.external_host}"
          say "Status: #{vhost.status}"

          case vhost.type
          when 'tcp', 'tls'
            ports = if vhost.container_ports.any?
                      vhost.container_ports.map(&:to_s).join(' ')
                    else
                      'all'
                    end
            say "Type: #{vhost.type}"
            say "Ports: #{ports}"
          when 'http', 'http_proxy_protocol'
            port = vhost.container_port ? vhost.container_port : 'default'
            say 'Type: https'
            say "Port: #{port}"
          end

          say "Internal: #{vhost.internal}"

          ip_whitelist = if vhost.ip_whitelist.any?
                           vhost.ip_whitelist.join(' ')
                         else
                           'all traffic'
                         end
          say "IP Whitelist: #{ip_whitelist}"

          say "Default Domain Enabled: #{vhost.default}"
          say "Default Domain: #{vhost.virtual_domain}" if vhost.default

          say "Managed TLS Enabled: #{vhost.acme}"
          if vhost.acme
            say "Managed TLS Domain: #{vhost.user_domain}"
            say 'Managed TLS DNS Challenge Hostname: ' \
                "#{vhost.acme_dns_challenge_host}"
            say "Managed TLS Status: #{vhost.acme_status}"
          end
        end

        def provision_vhost_and_explain(service, vhost)
          op = vhost.create_operation!(type: 'provision')
          attach_to_operation_logs(op)
          explain_vhost(service, vhost.reload)
          # TODO: Instructions if ACME is enabled?
        end

        def find_vhost(service_enumerator, hostname)
          seen = []

          service_enumerator.each do |service|
            service.each_vhost do |vhost|
              seen << vhost.external_host
              return vhost if vhost.external_host == hostname
            end
          end

          e = "Endpoint with hostname #{hostname} does not exist"
          e = "#{e} (valid hostnames: #{seen.join(', ')})" if seen.any?
          raise Thor::Error, e
        end

        def each_vhost(resource, &block)
          return enum_for(:each_vhost, resource) unless block_given?

          klass = resource.class
          if klass == Aptible::Api::App
            resource.each_service(&block)
          elsif klass == Aptible::Api::Database
            [resource.service].each(&block)
          else
            raise "Unexpected resource: #{klass}"
          end
        end
      end
    end
  end
end

module Aptible
  module CLI
    module Helpers
      module Vhost
        def explain_vhost(node, service, vhost)
          node.value('service', service.process_type)
          node.value('hostname', vhost.external_host)
          node.value('status', vhost.status)

          case vhost.type
          when 'tcp', 'tls'
            ports = if vhost.container_ports.any?
                      vhost.container_ports.map(&:to_s).join(' ')
                    else
                      'all'
                    end
            node.value('type', vhost.type)
            node.value('ports', ports)
          when 'http', 'http_proxy_protocol'
            port = vhost.container_port ? vhost.container_port : 'default'
            node.value('type', 'https')
            node.value('port', port)
          end

          # TODO: est these ints and booleans work in the output
          node.value('internal', vhost.internal)

          ip_whitelist = if vhost.ip_whitelist.any?
                           vhost.ip_whitelist.join(' ')
                         else
                           'all traffic'
                         end
          node.value('ip_whitelist', ip_whitelist)

          node.value('default_domain_enabled', vhost.default)
          node.value('default_domain', vhost.virtual_domain) if vhost.default

          node.value('managed_tls_enabled', vhost.acme)
          if vhost.acme
            node.value('managed_tls_domain', vhost.user_domain)
            node.value(
              'managed_tls_dns_challenge_hostname',
              vhost.acme_dns_challenge_host
            )
            node.value('managed_tls_status', vhost.acme_status)
          end
        end

        def provision_vhost_and_explain(service, vhost)
          op = vhost.create_operation!(type: 'provision')
          attach_to_operation_logs(op)

          Formatter.render(Renderer.current) do |root|
            root.object do |node|
              explain_vhost(node, service, vhost.reload)
            end
          end
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

        def each_service(resource, &block)
          return enum_for(:each_service, resource) if block.nil?
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

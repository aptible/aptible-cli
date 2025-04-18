module Aptible
  module CLI
    module Helpers
      module Vhost
        def provision_vhost_and_explain(service, vhost)
          op = vhost.create_operation!(type: 'provision')
          attach_to_operation_logs(op)

          Formatter.render(Renderer.current) do |root|
            root.object do |node|
              ResourceFormatter.inject_vhost(node, vhost.reload, service)
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
            # We could also raise the error here, but it would technically be a
            # breaking change:we currently return an empty list if the App is
            # not provisioned.
            # if resource.services.empty?
            #   raise Thor::Error, 'App is not provisioned'
            # end
            resource.each_service(&block)
          elsif klass == Aptible::Api::Database
            if resource.service.nil?
              raise Thor::Error, 'Database is not provisioned'
            end

            [resource.service].each(&block)
          else
            raise "Unexpected resource: #{klass}"
          end
        end
      end
    end
  end
end

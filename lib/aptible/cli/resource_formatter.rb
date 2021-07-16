module Aptible
  module CLI
    module ResourceFormatter
      class << self
        NO_NESTING = Object.new.freeze

        def inject_backup(node, backup, include_db: false)
          bu_operation = begin
                           backup.created_from_operation
                         rescue HyperResource::ClientError
                           nil
                         end

          origin = if backup.manual && !backup.copied_from
                     if bu_operation
                       "manual, #{bu_operation.user_email}"
                     else
                       'manual, unknown'
                     end
                   elsif backup.manual && backup.copied_from
                     'manual, copy'
                   elsif backup.copied_from
                     'automatic, copy'
                   else
                     'automatic'
                   end
          description = "#{backup.id}: #{backup.created_at}, " \
                        "#{backup.aws_region}, #{origin}"

          if include_db
            db = backup.database_with_deleted
            node.keyed_object('database', 'id') do |n|
              inject_deleted_database(n, db, backup.account)
            end

            description = "#{description}, " \
                          "#{db.handle} deleted at #{db.deleted_at}"
          end

          node.value('id', backup.id)
          node.value('description', description)
          node.value('created_at', backup.created_at)
          node.value('region', backup.aws_region)
          node.value('size', backup.size)
          node.value('manual', backup.manual)

          if backup.copied_from
            node.keyed_object('copied_from', 'description') do |n|
              inject_backup(n, backup.copied_from)
            end
          end

          if bu_operation && \
             backup.manual && !backup.copied_from
            node.keyed_object('created_from_operation', 'id') do |n|
              inject_operation(n, bu_operation)
            end
          end
        end

        def inject_deleted_database(node, database, account)
          node.value('id', database.id)
          node.value('handle', database.handle)
          node.value('type', database.type)
          node.value('deleted_at', database.deleted_at)
          attach_account(node, account)
        end

        def inject_account(node, account)
          node.value('id', account.id)
          node.value('handle', account.handle)
          node.value('created_at', account.created_at)
        end

        def inject_operation(node, operation)
          node.value('id', operation.id)
          node.value('status', operation.status)
          if %w(deploy rebuild).include?(operation.type)
            node.value('git_ref', operation.git_ref)
          end
          node.value('user_email', operation.user_email)
          node.value('created_at', operation.created_at)
        end

        def inject_app(node, app, account)
          node.value('id', app.id)
          node.value('handle', app.handle)
          node.value('created_at', app.created_at)

          node.value('status', app.status)
          node.value('git_remote', app.git_repo)

          if app.last_deploy_operation
            node.keyed_object('last_deploy_operation', 'id') do |n|
              inject_operation(n, app.last_deploy_operation)
            end
          end

          node.list('services') do |services_list|
            app.each_service do |service|
              services_list.object do |n|
                inject_service(n, service, NO_NESTING)
              end
            end
          end

          attach_account(node, account)
        end

        def inject_database(node, database, account)
          node.value('id', database.id)
          node.value('handle', database.handle)
          node.value('created_at', database.created_at)

          node.value('type', database.type)
          node.value('version', database.database_image.version)
          node.value('status', database.status)

          node.value('connection_url', database.connection_url)

          node.list('credentials') do |creds_list|
            database.database_credentials.each do |cred|
              creds_list.object { |n| inject_credential(n, cred) }
            end
          end
          attach_account(node, account)

          if database.disk
            node.value('disk_type', database.disk.ebs_volume_type)
            node.value('disk_size', database.disk.size)
            node.value('disk_modification_progress',
                       database.disk.modification_progress)
            node.value('disk_modification_status', database.disk.status)
            node.value('disk_provisioned_iops', database.disk.baseline_iops)
          end

          if database.service
            node.value('container_size', \
                       database.service.container_memory_limit_mb)
          end
        end

        def inject_credential(node, credential)
          # TODO: Should this accept a DB for nesting? Maybe if we have any
          # callers that could benefit from it.
          node.value('type', credential.type)
          node.value('connection_url', credential.connection_url)
          node.value('default', credential.default)
        end

        def inject_service(node, service, app)
          node.value('id', service.id)
          node.value('service', service.process_type)
          node.value('created_at', service.created_at)

          node.value('command', service.command || 'CMD')
          node.value('container_count', service.container_count)
          node.value('container_size', service.container_memory_limit_mb)

          attach_app(node, app)
        end

        def inject_vhost(node, vhost, service)
          node.value('id', vhost.id)
          node.value('hostname', vhost.external_host)
          node.value('status', vhost.status)
          node.value('created_at', vhost.created_at)

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

          attach_service(node, service)
        end

        private

        def attach_account(node, account)
          return if NO_NESTING.eql?(account)
          node.keyed_object('environment', 'handle') do |n|
            inject_account(n, account)
          end
        end

        def attach_app(node, app)
          return if NO_NESTING.eql?(app)
          node.keyed_object('app', 'handle') do |n|
            inject_app(n, app, NO_NESTING)
          end
        end

        def attach_service(node, service)
          return if NO_NESTING.eql?(service)
          node.keyed_object('service', 'service') do |n|
            inject_service(n, service, NO_NESTING)
          end
        end
      end
    end
  end
end

module Aptible
  module CLI
    module ResourceFormatter
      class << self
        NO_NESTING = Object.new.freeze

        def inject_backup(node, backup, include_db: false)
          description = "#{backup.id}: #{backup.created_at}, " \
                        "#{backup.aws_region}"

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
        end

        def inject_operation(node, op)
          preposition = {
            'running' => 'for',
            'queued' => 'for',
            'failed' => 'after',
            'succeeded' => 'after'
          }

          finished = %w(failed succeeded).include?(op.status)
          finished_at = finished ? op.updated_at : Time.now
          duration = (finished_at - op.created_at).round
          duration = "#{duration / 60}:#{(duration % 60).to_s.rjust(2, '0')}"
          duration = "#{duration}+" unless finished

          ram_size = op.container_size
          disk_size = op.disk_size

          if op.type == 'deploy'
            if op.git_ref == '0000000000000000000000000000000000000000'
              deployment_artifact = ' of docker_image: '\
                                    "#{op.env['APTIBLE_DOCKER_IMAGE']}"
              node_value('docker_image', op.env['APTIBLE_DOCKER_IMAGE'])
            elsif op.git_ref
              deployment_artifact = " of git_ref: \"#{op.git_ref}\""
            elsif op.env
              deployment_artifact = ' of docker_image: '\
                                    "\"#{op.env['APTIBLE_DOCKER_IMAGE']}\""
              # node_value('docker_image', op.env['APTIBLE_DOCKER_IMAGE'])
            else
              deployment_artifact = ' What was deployed?'
            end
          end

          description = "#{op.id}: #{op.created_at}, " \
                        "#{op.type}#{deployment_artifact} " \
                        "#{op.status} #{preposition[op.status]} " \
                        "#{duration}, " \
                        "#{op.user_email}"

          node.value('id', op.id)
          node.value('status', op.status)
          node.value('git_ref', op.git_ref)
          node.value('user_email', op.user_email)
          node.value('created_at', op.created_at)
          node.value('operation', op.type)
          node.value('duration', duration)

          case op.type
          when 'restart'
            if ram_size
              node.value('container_size', ram_size)
              description += ", container size: #{ram_size}mb"
            end
            if disk_size && disk_size > 0
              node.value('disk_size', disk_size)
              description += ", disk size: #{disk_size}gb"
            end
          when 'deploy'
            true
          when 'execute'
            node.value('command', op.command)
            description += ", command: \"#{op.command}\""
          end

          node.value('description', description)
        end

        def inject_app(node, app, account)
          node.value('id', app.id)
          node.value('handle', app.handle)

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

          node.value('command', service.command || 'CMD')
          node.value('container_count', service.container_count)
          node.value('container_size', service.container_memory_limit_mb)

          attach_app(node, app)
        end

        def inject_vhost(node, vhost, service)
          node.value('id', vhost.id)
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

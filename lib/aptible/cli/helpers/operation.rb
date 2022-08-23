require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module Operation
        include Helpers::Ssh

        POLL_INTERVAL = 1

        def poll_for_success(operation)
          wait_for_completion operation
          return if operation.status == 'succeeded'

          raise Thor::Error, "Operation ##{operation.id} failed."
        end

        def wait_for_completion(operation)
          while %w(queued running).include? operation.status
            sleep 1
            operation.get
          end
        end

        def attach_to_operation_logs(operation)
          # TODO: This isn't actually guaranteed to connect to the operation
          # logs, since the action will depend on what operation we're actually
          # connecting for. There might be ways to make this better.
          ENV['ACCESS_TOKEN'] = fetch_token

          code = connect_to_ssh_portal(
            operation,
            '-o', 'SendEnv=ACCESS_TOKEN'
          )

          # If the portal is down, fall back to polling for success. If the
          # operation failed, poll_for_success will immediately fall through to
          # the error message.
          unless code == 0
            e = 'Disconnected from logs, waiting for operation to complete'
            CLI.logger.warn e
            poll_for_success(operation)
          end
        end

        def cancel_operation(operation)
          CLI.logger.info "Cancelling #{prettify_operation(operation)}..."
          operation.update!(cancelled: true)
        end

        def operation_logs(operation)
          # go to s3 operation logs endpoint
          uri = URI("#{Aptible::Auth.configuration.root_url}/operations/#{operation.id}/logs")

          headers = { "Authorization" => "bearer #{fetch_token}" }
          http = Net::HTTP.new(uri[:host], uri.port)
          http.use_ssl = true
          res = http.get(uri[:path], headers)

          if res.code != 301 or !res.header?('location')
            e = 'Unable to retrieve operation logs. Redirect to destination not found.'
            raise Thor::Error, e
          end

          # follow the link with redirect
          s3_file = Net::HTTP.get_response(URI.parse(res.header?['location']))

          # download/spit out logs from s3
          CLI.logger.info "Printing out results of operation logs"
          puts s3_file.body
        end

        def prettify_operation(o)
          bits = [o.status, o.type, "##{o.id}"]
          if o.resource.respond_to?(:handle)
            bits.concat ['on', o.resource.handle]
          end
          bits.join ' '
        end
      end
    end
  end
end

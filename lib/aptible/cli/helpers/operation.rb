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
          res = get_operation_logs_redirect(operation)
          if !res || (res.code != '301' || !res.header.fetch(:location))
            e = 'Unable to retrieve operation logs. Redirect not found.'
            raise Thor::Error, e
          end

          # follow the link with redirect
          s3_uri = URI(res.header.fetch(:location))
          s3_file = http.request(Net::HTTP::Get.new(s3_uri.request_uri))

          # download/spit out logs from s3
          m = "Printing out results of operation logs for #{operation.id}"
          CLI.logger.info m
          puts s3_file.body
        end

        def prettify_operation(o)
          bits = [o.status, o.type, "##{o.id}"]
          if o.resource.respond_to?(:handle)
            bits.concat ['on', o.resource.handle]
          end
          bits.join ' '
        end

        private

        def get_operation_logs_redirect(operation)
          # go to s3 operation logs endpoint
          uri = URI(Aptible::Api.configuration.root_url.to_s +
                      "/operations/#{operation.id}/logs")
          headers = { 'Authorization' => "bearer #{fetch_token}" }
          request = Net::HTTP::Get.new(uri.request_uri, headers)

          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          http.request(request)
        end
      end
    end
  end
end

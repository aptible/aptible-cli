require 'aptible/api'
require 'net/http'

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
            msg = ['Disconnected from logs, waiting for operation to complete',
                   'Once complete, the logs can be viewed here:',
                   "    #{ui_log_url(operation)}"]
            msg.each { |e| CLI.logger.warn e }
            poll_for_success(operation)
          end
        end

        def cancel_operation(operation)
          CLI.logger.info "Cancelling #{prettify_operation(operation)}..."
          operation.update!(cancelled: true)
        end

        def operation_logs(operation)
          res = get_operation_logs_redirect(operation)
          s3_file_request = get_operation_logs_s3_file(res.body)

          m = "Printing out results of operation logs for #{operation.id}"
          CLI.logger.info m
          puts s3_file_request.body
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
          uri = URI(operation.logs_url)
          headers = { 'Authorization' => "Bearer #{fetch_token}" }
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          res = http.request(Net::HTTP::Get.new(uri.request_uri, headers))
          # note: res body with a 200 is target redirect location for download
          if !res || res.code != '200' || res.body.nil?
            raise Thor::Error, 'Unable to retrieve the operation\'s logs. ' \
            'If the issue persists please contact support for assistance, or ' \
            "view them at #{ui_log_url(operation)}"
          end
          res
        end

        def get_operation_logs_s3_file(location)
          s3_uri = URI(location)
          http = Net::HTTP.new(s3_uri.host, s3_uri.port)
          http.use_ssl = true

          # follow the link with redirect and retrieve it from s3 directly
          res = http.request(Net::HTTP::Get.new(s3_uri.request_uri))
          if !res || res.code != '200'
            raise Thor::Error, 'Unable to retrieve operation logs, '\
              "S3 returned response code #{res.code}. "\
              'If the issue persists please contact support for assistance.'
          end
          res
        end

        def ui_log_url(operation)
          "https://app.aptible.com/operations/#{operation.id}"
        end
      end
    end
  end
end

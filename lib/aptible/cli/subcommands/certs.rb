module Aptible
  module CLI
    module Subcommands
      module Certs
        def self.included(thor)
          thor.class_eval do
            include Helpers::Environment
            include Helpers::Token

            desc 'certs', 'List all certificates'
            option :environment
            def certs
              scoped_environments(options).each do |env|
                say "=== #{env.handle}"

                env.certificates.each do |cert|
                  cert_start = Date.parse(cert.not_before).iso8601
                  cert_end = Date.parse(cert.not_after).iso8601

                  # 123: *.example.com, COMODO, valid 2016-01-01 - 2016-01-01
                  say "#{cert.id}: " \
                  "'#{cert.common_name}', " \
                    "#{cert.issuer_organization}, " \
                    "valid #{cert_start} - #{cert_end}"
                end

                say ''
              end
            end
          end
        end
      end
    end
  end
end

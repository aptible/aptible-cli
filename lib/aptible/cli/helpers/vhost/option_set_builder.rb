module Aptible
  module CLI
    module Helpers
      module Vhost
        class OptionSetBuilder
          FLAGS = %i(
            environment
            app
            database
            tls
            ports
            port
          ).freeze

          def initialize(&block)
            FLAGS.each { |f| instance_variable_set("@#{f}", false) }
            instance_exec(&block) if block
          end

          def declare_options(thor)
            thor.instance_exec(self) do |builder|
              option :environment

              if builder.app?
                app_options
                option(
                  :default_domain,
                  type: :boolean,
                  desc: 'Whether to enable Default Domain on this Endpoint'
                )

                option(
                  :internal,
                  type: :boolean,
                  desc: 'Whether to restrict this Endpoint to internal traffic'
                )

                if builder.ports?
                  option(
                    :ports,
                    type: :array,
                    desc: 'Specify a list of ports to expose on this Endpoint'
                  )
                end

                if builder.port?
                  option(
                    :port,
                    type: :numeric,
                    desc: 'Specify a port to expose on this Endpoint'
                  )
                end
              end

              option(
                :ip_whitelist,
                type: :array,
                desc: 'Restrict traffic to this Endpoint to a list of IP ' \
                      'sources (addresses or CIDRs)'
              )

              if builder.tls?
                option(
                  :certificate_file,
                  type: :string,
                  desc: 'A file containing a certificate to use on this ' \
                        'Endpoint'
                )
                option(
                  :private_key_file,
                  type: :string,
                  desc: 'A file containing a private key to use on this ' \
                        'Endpoint'
                )

                option(
                  :managed_tls,
                  type: :boolean,
                  desc: 'Whether to enable Managed TLS on this Endpoint'
                )

                option(
                  :managed_tls_domain,
                  desc: 'The domain to use for Managed TLS'
                )

                option(
                  :certificate_fingerprint,
                  type: :string,
                  desc: 'The fingerprint of an existing Certificate to use ' \
                        'on this Endpoint'
                )
              end
            end
          end

          def prepare(account, options)
            options = options.dup # We're going to delete keys here
            verify_option_conflicts(options)

            params = {}

            params[:ip_whitelist] = options.delete(:ip_whitelist) { [] }

            params[:container_port] = options.delete(:port) if port?

            if ports?
              raw_ports = options.delete(:ports) { [] }
              params[:container_ports] = raw_ports.map do |p|
                begin
                  Integer(p)
                rescue ArgumentError
                  m = "Invalid port: #{p}"
                  raise Thor::Error, m
                end
              end
            end

            if app?
              params[:internal] = !!options.delete(:internal) { false }
              params[:default] = !!options.delete(:default_domain) { false }
              options.delete(:app)
            else
              params[:internal] = false
            end

            process_tls(account, options, params) if tls?

            options.delete(:environment)

            # NOTE: This is here to ensure that specs don't test for options
            # that are not declared. This is not expected to happen when using
            # this.
            raise "Unexpected options: #{options}" if options.any?

            params
          end

          FLAGS.each do |f|
            define_method("#{f}?") { instance_variable_get("@#{f}") }
          end

          private

          FLAGS.each do |f|
            define_method("#{f}!") { instance_variable_set("@#{f}", true) }
          end

          def process_tls(account, options_in, params_out)
            # Certificate fingerprint option
            if (fingerprint = options_in.delete(:certificate_fingerprint))
              params_out[:certificate] = find_certificate(account, fingerprint)
            end

            # Ad-hoc certificate option
            certificate_file = options_in.delete(:certificate_file)
            private_key_file = options_in.delete(:private_key_file)

            if certificate_file || private_key_file
              if certificate_file.nil?
                raise Thor::Error, "Missing #{to_flag(:certificate_file)}"
              end

              if private_key_file.nil?
                raise Thor::Error, "Missing #{to_flag(:private_key_file)}"
              end

              opts = begin
                       {
                         certificate_body: File.read(certificate_file),
                         private_key: File.read(private_key_file)
                       }
                     rescue StandardError => e
                       m = 'Failed to read certificate or private key ' \
                         "file: #{e}"
                       raise Thor::Error, m
                     end

              params_out[:certificate] = account.create_certificate!(opts)
            end

            # ACME option
            acme = params_out[:acme] = options_in.delete(:managed_tls) { false }
            if acme
              user_domain = options_in.delete(:managed_tls_domain)
              e = "#{to_flag(:managed_tls_domain)} is required to enable " \
                  'Managed TLS'
              raise Thor::Error, e if user_domain.nil?
              params_out[:user_domain] = user_domain
            end
          end

          def find_certificate(account, fingerprint)
            matches = []
            account.each_certificate do |certificate|
              if certificate.sha256_fingerprint == fingerprint
                return certificate
              end

              if certificate.sha256_fingerprint.start_with?(fingerprint)
                matches << certificate
              end
            end

            matches = matches.uniq(&:sha256_fingerprint)

            case matches.size
            when 0
              e = "No certificate matches fingerprint #{fingerprint}"
              raise Thor::Error, e
            when 1
              return matches.first
            else
              e = 'Too many certificates match fingerprint ' \
                  "#{fingerprint}, pass a more specific fingerprint "
              raise Thor::Error, e
            end
          end

          def verify_option_conflicts(options)
            certificate_options = [
              %i(certificate_file private_key_file),
              %i(certificate_fingerprint),
              %i(managed_tls managed_tls_domain),
              %i(default_domain)
            ]

            matches = certificate_options.map do |g|
              g.any? { |k| !!options[k] }
            end

            if matches.select { |m| !!m }.size > 1
              selected = certificate_options.flatten.select do |o|
                !!options[o]
              end

              flags = selected.map { |s| to_flag(s) }
              e = "Conflicting options provided: #{flags.join(', ')}"
              raise Thor::Error, e
            end
          end

          def to_flag(sym)
            "--#{sym.to_s.tr('_', '-')}"
          end
        end
      end
    end
  end
end

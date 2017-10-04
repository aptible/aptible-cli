module Aptible
  module CLI
    module Helpers
      module Vhost
        class OptionSetBuilder
          FLAGS = %i(
            environment
            app
            database
            create
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

                if builder.create?
                  option(
                    :default_domain,
                    type: :boolean,
                    desc: 'Enable Default Domain on this Endpoint'
                  )

                  option(
                    :internal,
                    type: :boolean,
                    desc: 'Restrict this Endpoint to internal traffic'
                  )
                end

                if builder.ports?
                  option(
                    :ports,
                    type: :array,
                    desc: 'A list of ports to expose on this Endpoint'
                  )
                end

                if builder.port?
                  option(
                    :port,
                    type: :numeric,
                    desc: 'A port to expose on this Endpoint'
                  )
                end
              end

              option(
                :ip_whitelist,
                type: :array,
                desc: 'A list of IPv4 sources (addresses or CIDRs) to ' \
                      'which to restrict traffic to this Endpoint'
              )

              unless builder.create?
                # Yes, it has to be a dash...
                # See: https://github.com/erikhuda/thor/pull/551
                option(
                  :'no-ip_whitelist',
                  type: :boolean,
                  desc: 'Disable IP Whitelist'
                )
              end

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
                  desc: 'Enable Managed TLS on this Endpoint'
                )

                option(
                  :managed_tls_domain,
                  desc: 'A domain to use for Managed TLS'
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

            params[:ip_whitelist] = options.delete(:ip_whitelist) do
              create? ? [] : nil
            end

            if options.delete(:'no-ip_whitelist') { false }
              params[:ip_whitelist] = []
            end

            params[:container_port] = options.delete(:port) if port?

            if ports?
              raw_ports = options.delete(:ports) do
                create? ? [] : nil
              end

              if raw_ports
                params[:container_ports] = raw_ports.map do |p|
                  begin
                    Integer(p)
                  rescue ArgumentError
                    m = "Invalid port: #{p}"
                    raise Thor::Error, m
                  end
                end
              end
            end

            if app?
              params[:internal] = options.delete(:internal) do
                create? ? false : nil
              end

              params[:default] = options.delete(:default_domain) do
                create? ? false : nil
              end

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

            params.delete_if { |_, v| v.nil? }
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
            params_out[:acme] = options_in.delete(:managed_tls) do
              create? ? false : nil
            end

            params_out[:user_domain] = options_in.delete(:managed_tls_domain)

            if create? && params_out[:acme] && params_out[:user_domain].nil?
              e = "#{to_flag(:managed_tls_domain)} is required to enable " \
                  'Managed TLS'
              raise Thor::Error, e
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
            conflict_groups = [
              [
                %i(certificate_file private_key_file),
                %i(certificate_fingerprint),
                %i(managed_tls managed_tls_domain),
                %i(default_domain)
              ],
              [
                %i(no-ip_whitelist),
                %i(ip_whitelist)
              ]
            ]

            conflict_groups.each do |group|
              matches = group.map do |g|
                g.any? { |k| !!options[k] }
              end

              next unless matches.select { |m| !!m }.size > 1

              selected = group.flatten.select do |o|
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

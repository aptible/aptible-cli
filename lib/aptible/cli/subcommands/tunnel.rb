module Aptible
  module CLI
    module Subcommands
      module Tunnel
        # rubocop:disable MethodLength
        def self.included(thor)
          thor.class_eval do
            include Helpers::Operation
            include Helpers::Token

            desc 'tunnel DATABASE', 'Create a local tunnel to a database'
            def tunnel(handle)
              database = database_from_handle(handle)
              unless database
                fail Thor::Error, "Could not find database #{handle}"
              end
              host = database.account.bastion_host
              port = database.account.bastion_port

              ENV['APTIBLE_DATABASE'] = handle
              tunnel_args = "-L #{local_port}:localhost:#{remote_port}"
              connection_args = "-o 'SendEnv=*' -p #{port} root@#{host}"
              puts "Creating tunnel at localhost:#{local_port}..."
              Kernel.exec "ssh #{tunnel_args} #{connection_args}"
            end

            private

            def database_from_handle(handle)
              Aptible::Api::Database.all(token: fetch_token).find do |a|
                a.handle == handle
              end
            end

            def local_port
              return @local_port if @local_port

              # Allocate a dummy server to discover an available port
              dummy = TCPServer.new('127.0.0.1', 0)
              port = dummy.addr[1]
              dummy.close
              @local_port = port
            end

            def remote_port
              8080
            end
          end
        end
        # rubocop:enable MethodLength
      end
    end
  end
end

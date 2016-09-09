module Aptible
  module CLI
    module Helpers
      module Ssh
        def dumptruck_ssh_command(account)
          base_ssh_command(account, :dumptruck_port)
        end

        def broadwayjoe_ssh_command(account)
          base_ssh_command(account, :bastion_port)
        end

        private

        def base_ssh_command(account, port_method)
          log_level = ENV['APTIBLE_SSH_VERBOSE'] ? 'VERBOSE' : 'ERROR'

          [
            'ssh',
            "root@#{account.bastion_host}",
            '-p', account.public_send(port_method).to_s,
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=/dev/null',
            '-o', 'TCPKeepAlive=yes',
            '-o', 'KeepAlive=yes',
            '-o', 'ServerAliveInterval=60',
            '-o', "LogLevel=#{log_level}"
          ]
        end
      end
    end
  end
end

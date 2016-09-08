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
          [
            'ssh',
            "root@#{account.bastion_host}",
            '-p', account.public_send(port_method).to_s,
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=/dev/null',
            '-o', 'TCPKeepAlive=yes',
            '-o', 'KeepAlive=yes',
            '-o', 'ServerAliveInterval=60',
            # TODO: Test whether this LogLevel affects open port fail
            '-o', 'LogLevel=quiet'
          ]
        end
      end
    end
  end
end

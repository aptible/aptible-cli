module Aptible
  module CLI
    module Helpers
      module Ssh
        def connect_to_ssh_portal(operation, *extra_ssh_args)
          with_ssh_cmd(operation) do |base_ssh_cmd|
            ssh_cmd = base_ssh_cmd + extra_ssh_args
            begin
              Kernel.system(*ssh_cmd)
            rescue Interrupt
              # Assuming we have a TTY, there are two cases here. Either SSH
              # itself has a TTY, in which case it is controlling the TTY and
              # the CLI won't be receiving SIGINT when CTRL+C is pressed, or
              # SSH has no TTY, in which case the CLI and SSH are sharing the
              # same process group, and will both receive SIGINT when CTRL+C
              # is pressed and exit accordingly.
              #
              # I'm not sure how this *should* work on Windows, but it appears
              # to work pretty much the same way, except that we'll get an ugly
              # "Terminate batch job (Y/N)?" prompt in the no-TTY-for-SSH case,
              # which we're likely to have a hard time handling.
              #
              # Note that this DOES NOT handle the case where the CLI is sent
              # SIGINT by another process (as opposed to the line discipline).
              # In this case, SSH will continue running in the background. This
              # is something we should fix, but for now this 'simple' fix is
              # enough to addresses the ugly stack trace we show when
              # CTRL+C'ing out of logs.
            end
          end
        end

        def with_ssh_cmd(operation)
          ensure_ssh_dir!
          ensure_config!
          ensure_key!

          operation.with_ssh_cmd(private_key_file) do |cmd, connection|
            yield cmd + common_ssh_args, connection
          end
        end

        private

        def ensure_ssh_dir!
          FileUtils.mkdir_p(ssh_dir, mode: 0o700)
        end

        def ensure_config!
          return if File.exist?(ssh_config_file)
          File.open(ssh_config_file, 'w', 0o600) { |f| f.write('') }
        end

        def ensure_key!
          key_files = [private_key_file, public_key_file]
          return if key_files.all? { |f| File.exist?(f) }

          # If we're missing *some* files, then we should clean them up.

          key_files.each do |key_file|
            begin
              File.delete(key_file)
            rescue Errno::ENOENT
              # We don't care, that's what we want.
            end
          end

          begin
            cmd = ['ssh-keygen', '-t', 'rsa', '-N', '', '-f', private_key_file]
            out, status = Open3.capture2e(*cmd)
            raise "Failed to generate ssh key: #{out}" unless status.success?
          rescue Errno::ENOENT
            raise 'ssh-keygen must be installed'
          end
        end

        def ssh_dir
          File.join ENV['HOME'], '.aptible', 'ssh'
        end

        def ssh_config_file
          File.join ssh_dir, 'config'
        end

        def private_key_file
          File.join ssh_dir, 'id_rsa'
        end

        def public_key_file
          "#{private_key_file}.pub"
        end

        def common_ssh_args
          log_level = ENV['APTIBLE_SSH_DEBUG'] ? 'DEBUG3' : 'ERROR'

          [
            '-o', 'TCPKeepAlive=yes',
            '-o', 'KeepAlive=yes',
            '-o', 'ServerAliveInterval=60',
            '-o', "LogLevel=#{log_level}",
            '-o', 'ControlMaster=no',
            '-o', 'ControlPath=none',
            '-F', ssh_config_file
          ]
        end
      end
    end
  end
end

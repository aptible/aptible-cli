module Aptible
  module CLI
    module Helpers
      module Ssh
        def connect_to_ssh_portal(operation, *extra_ssh_args)
          # TODO: Should we rescue Interrupt here?
          with_ssh_cmd(operation) do |base_ssh_cmd|
            ssh_cmd = base_ssh_cmd + extra_ssh_args
            Kernel.system(*ssh_cmd)
          end
        end

        def with_ssh_cmd(operation)
          ensure_key!

          operation.with_ssh_cmd(private_key_file) do |cmd, connection|
            yield cmd + common_ssh_args, connection
          end
        end

        private

        def ensure_key!
          key_files = [private_key_file, public_key_file]
          return if key_files.all? { |f| File.exist?(f) }

          # If we don't have all the files, we may either not have the
          # directory (and any files), have the directory but no files,
          # or the directory but some files. We need to converge to the
          # known good state where we can create them: the directory exists
          # and none of the files do.
          FileUtils.mkdir_p(ssh_keydir)

          # rubocop:disable Lint/HandleExceptions
          key_files.each do |key_file|
            begin
              File.delete(key_file)
            rescue Errno::ENOENT
              # We don't care, that's what we want.
            end
          end
          # rubocop:enable Lint/HandleExceptions

          begin
            cmd = ['ssh-keygen', '-t', 'rsa', '-N', '', '-f', private_key_file]
            out, status = Open3.capture2e(*cmd)
            raise "Failed to generate ssh key: #{out}" unless status.success?
          rescue Errno::ENOENT
            raise 'ssh-keygen must be installed'
          end
        end

        def ssh_keydir
          File.join ENV['HOME'], '.aptible', 'ssh'
        end

        def private_key_file
          File.join ssh_keydir, 'id_rsa'
        end

        def public_key_file
          "#{private_key_file}.pub"
        end

        def common_ssh_args
          log_level = ENV['APTIBLE_SSH_VERBOSE'] ? 'VERBOSE' : 'ERROR'

          [
            '-o', 'StrictHostKeyChecking=no',
            '-o', 'UserKnownHostsFile=/dev/null',
            '-o', 'TCPKeepAlive=yes',
            '-o', 'KeepAlive=yes',
            '-o', 'ServerAliveInterval=60',
            '-o', "LogLevel=#{log_level}",
            '-o', 'ControlMaster=no',
            '-o', 'ControlPath=none'
          ]
        end
      end
    end
  end
end

module Aptible
  module CLI
    module Helpers
      module Ssh
        def connect_to_ssh_portal(operation, *extra_ssh_args)
          # NOTE: This is a little tricky to get rigt, so before you make any
          # changes, read this.
          #
          # - The first gotcha is that we cannot use Kernel.exec here, because
          # we need to perform cleanup when exiting from
          # operation#with_ssh_cmd.
          #
          # - The second gotcha is that we need to somehow capture the exit
          # status, so that CLI commands that call the SSH portal can proxy
          # this back to their own caller (the most important one here is
          # aptible ssh).
          #
          # To do this, we have to handle interrutps as a signal, as opposed to
          # handle an Interrupt exception. The reason for this has to do with
          # how Ruby's wait is implemented (this happens in process.c's
          # rb_waitpid). There are two main considerations here:
          #
          # - It automatically resumes when it receives EINTR, so our control
          # is pretty high-level here.
          # - It handles interrupts prior to setting $? (this appears to have
          # changed between Ruby 2.2 and 2.3, perhaps the newer implementation
          # behaves differently).
          #
          # Unfortunately, this means that if we receive SIGINT while in
          # Process::wait2, then we never get access to SSH's exitstatus: Ruby
          # throws a Interrupt so we don't have a return value, and it doesn't
          # set $?, so we can't read it back there.
          #
          # Of course, we can't just call Proces::wait2 again, because at this
          # point, we've reaped our child.
          #
          # To solve this, we add our own signal handler on SIGINT, which
          # simply proxies SIGINT to SSH if we happen to have a different
          # process group (which shouldn't be the case), just to be safe and
          # let users exit the CLI.
          with_ssh_cmd(operation) do |base_ssh_cmd|
            spawn_passthrough(base_ssh_cmd + extra_ssh_args)
          end
        end

        def exit_with_ssh_portal(*args)
          exit connect_to_ssh_portal(*args)
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

        def spawn_passthrough(command)
          redirection = { in: :in, out: :out, err: :err, close_others: true }
          pid = Process.spawn(*command, redirection)

          reset = Signal.trap('SIGINT') do
            # FIXME: If we're on Windows, we don't really know whether SSH
            # received SIGINT or not, so for now, we just ignore it.
            next if Gem.win_platform?

            begin
              # SSH should be running in our process group, which means that
              # if the user sends CTRL+C, we'll both receive it. In this
              # case, just ignore the signal and let SSH handle it.
              next if Process.getpgid(Process.pid) == Process.getpgid(pid)

              # If we get here, then oddly, SSH is not running in our process
              # group and yet we got the signal. In this case, let's simply
              # ignore it.
              Process.kill(:SIGINT, pid)
            rescue Errno::ESRCH
              # This could happen if SSH exited after receiving the SIGINT,
              # Ruby waited it, then ran our signal handler. In this case, we
              # don't need to do anything, so we proceed.
            end
          end

          begin
            _, status = Process.wait2(pid)
            return status.exited? ? status.exitstatus : 128 + status.termsig
          ensure
            Signal.trap('SIGINT', reset)
          end
        end

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

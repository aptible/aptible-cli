require 'socket'
require 'open3'
require 'win32-process' if Gem.win_platform?

module Aptible
  module CLI
    module Helpers
      STOP_SIGNAL = if Gem.win_platform?
                      :SIGBRK
                    else
                      :SIGHUP
                    end

      STOP_TIMEOUT = 5

      # The :new_pgroup key specifies the CREATE_NEW_PROCESS_GROUP flag for
      # CreateProcessW() in the Windows API. This is a Windows only option.
      # true means the new process is the root process of the new process
      # group. This flag is necessary to be able to signal the subprocess on
      # Windows.
      SPAWN_OPTS = if Gem.win_platform?
                     { new_pgroup: true }
                   else
                     {}
                   end

      class Tunnel
        def initialize(env, ssh_cmd, socket_path)
          @env = env
          @ssh_cmd = ssh_cmd
          @socket_path = socket_path
        end

        def start(desired_port = 0)
          @local_port = desired_port
          @local_port = random_local_port if @local_port.zero?

          tunnel_cmd = @ssh_cmd + [
            '-L', "#{@local_port}:#{@socket_path}",
            '-o', 'ExitOnForwardFailure=yes'
          ]

          out_read, out_write = IO.pipe
          err_read, err_write = IO.pipe

          @pid = Process.spawn(@env, *tunnel_cmd, SPAWN_OPTS
            .merge(in: :close, out: out_write, err: err_write))

          # Wait for the tunnel to come up before returning. The other end
          # will send a message on stdout to indicate that the tunnel is ready.
          [out_write, err_write].map(&:close)
          begin
            out_read.readline
          rescue EOFError
            stop
            raise UserError, "Tunnel did not come up: #{err_read.read}"
          ensure
            [out_read, err_read].map(&:close)
          end
        end

        def stop
          raise 'You must call #start before calling #stop' if @pid.nil?

          begin
            Process.kill(STOP_SIGNAL, @pid)
          rescue Errno::ESRCH
            # Already dead.
            return
          end

          begin
            STOP_TIMEOUT.times do
              return if Process.wait(@pid, Process::WNOHANG)
              sleep 1
            end
            Process.kill(:SIGKILL, @pid)
          rescue Errno::ECHILD, Errno::ESRCH
            # Died at some point, that's fine.
          end
        end

        def wait
          # NOTE: Ruby is kind enough to retry when EINTR is thrown, so we
          # don't need to retry or anything here.
          _, status = Process.wait2(@pid)

          code = status.exitstatus

          case code
          when 0
            # No-op: we're happy with this.
          when 124
            raise Thor::Error, 'Tunnel timed out'
          else
            raise Thor::Error, "Tunnel crashed (#{code})"
          end
        end

        def port
          raise 'You must call #start before calling #port!' if @local_port.nil?
          @local_port
        end

        private

        def random_local_port
          # Allocate a dummy server to discover an available port
          dummy = TCPServer.new('127.0.0.1', 0)
          port = dummy.addr[1]
          dummy.close
          port
        end
      end
    end
  end
end

require 'socket'
require 'open3'
require 'win32-process' if Gem.win_platform?

module Aptible
  module CLI
    module Helpers
      # The :new_pgroup key specifies the CREATE_NEW_PROCESS_GROUP flag for
      # CreateProcessW() in the Windows API. This is a Windows only option.
      # true means the new process is the root process of the new process
      # group.
      # This flag is necessary for Process.kill(:SIGINT, pid) on the
      # subprocess.
      STOP_SIGNAL = if Gem.win_platform?
                      :SIGINT
                    else
                      :SIGHUP
                    end
      SPAWN_OPTS =  if Gem.win_platform?
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
            e = 'Tunnel did not come up, is something else listening on port ' \
                "#{@local_port}?\n#{err_read.read}"
            raise e
          ensure
            [out_read, err_read].map(&:close)
          end
        end

        def stop
          fail 'You must call #start before calling #stop' if @pid.nil?
          begin
            Process.kill(STOP_SIGNAL, @pid)
          rescue Errno::ESRCH
            nil # Dear Rubocop: I know what I'm doing.
          end
          wait
        end

        def wait
          Process.wait @pid
        rescue Errno::ECHILD
          nil
        end

        def port
          fail 'You must call #start before calling #port!' if @local_port.nil?
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

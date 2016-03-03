require 'socket'
require 'open3'

module Aptible
  module CLI
    module Helpers
      class Tunnel
        def initialize(env, cmd)
          @env = env
          @cmd = cmd
        end

        def start(desired_port = 0, err_fd = $stderr)
          @local_port = desired_port
          @local_port = random_local_port if @local_port == 0

          # First, grab a remote port
          out, err, status = Open3.capture3(@env, *@cmd)
          fail "Failed to request remote port: #{err}" unless status.success?

          # Then, spin up a SSH session using that port and port forwarding
          remote_port = out.chomp
          tunnel_env = @env.merge('TUNNEL_PORT' => remote_port)
          tunnel_cmd = @cmd + ['-L', "#{@local_port}:localhost:#{remote_port}"]

          r_pipe, w_pipe = IO.pipe
          @pid = Process.spawn(tunnel_env, *tunnel_cmd, in: :close,
                                                        out: w_pipe,
                                                        err: err_fd)

          # Wait for the tunnel to come up before returning. The other end
          # will send a message on stdout to indicate that the tunnel is ready.
          w_pipe.close
          begin
            r_pipe.readline
          rescue EOFError
            raise 'Server closed the tunnel'
          end
        end

        def stop
          fail 'You must call #start before calling #stop' if @pid.nil?
          Process.kill('HUP', @pid)
          wait
        end

        def wait
          Process.wait @pid
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

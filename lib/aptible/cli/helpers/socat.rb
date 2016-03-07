require 'socket'
require 'open3'

module Aptible
  module CLI
    module Helpers
      class Socat
        BUFFER_SIZE = 4096
        SELECT_TIMEOUT = 1
        # TODO: Benchmark peformance against old.

        def initialize(env, command, log_fd = $stderr)
          @env = env
          @command = command
          @log_fd = log_fd
        end

        def start(port = 0)
          # TODO: Consider not allowing re-starting
          q = Queue.new
          @thread =  Thread.new do
            begin
              run_socat_loop(@env, @command, port, q)
            # rubocop:disable Lint/RescueException
            rescue Exception => e
              @log_fd.puts "Socat thread crashed!: #{e.message}"
              @log_fd.puts e.backtrace
              raise
            end
          end
          @port = q.deq
        end

        def wait
          @thread.join
        end

        def stop
          @stop_requested = true
          wait
        end

        def port
          fail 'You must call #start before calling #port!' if @port.nil?
          @port
        end

        private

        def run_socat_loop(env, command, port = 0, signal_q = nil)
          @stop_requested = false

          buffer = ''
          fd_map = {}

          serv = TCPServer.new(port)

          signal_q.enq(serv.addr[1]) unless signal_q.nil?

          loop do
            break if @stop_requested

            # TODO: Non blocking writes.
            # We should check that writers are ready to avoid blocking
            # the entire event loop on an unavailable writer. This adds
            # a lot of complexity because we must handle cases where a
            # writer is ready, but not for all the data we read (i.e. we'd
            # need to buffer in here). For now, we're making blocking
            # writes.

            begin
              for_read, _, _ = IO.select(fd_map.keys + [serv], [], [],
                                         SELECT_TIMEOUT)
            rescue Interrupt
              # Probably CTRL+C or a signal. Expect another thread will set
              # @stop_requested
              next
            rescue IOError
              # Oops, we have a closed stream somewhere: prune our streams.
              fd_map.keys.each do |fd|
                close_read_fd(fd_map, fd) if fd.closed?
              end
              next
            end

            # If we timed out, don't try reading anything!
            next if for_read.nil?

            for_read.each do |io|
              if io == serv
                sock = serv.accept_nonblock
                stdin, stdout, stderr, _ = Open3.popen3(env, *command)

                fd_map.merge!(
                  sock => stdin,
                  stdout => sock,
                  stderr => @log_fd
                )
                next
              end

              dest_fd = fd_map[io]
              fail "Unexpected fd was ready: #{io}" if dest_fd.nil?

              begin
                io.read_nonblock(BUFFER_SIZE, buffer)
              rescue IO::WaitReadable
                retry
              rescue EOFError
                # Oops, the input fd is closed. Stop reading from it, and
                # close the output end (unless it's already closed!).
                close_read_fd(fd_map, io)
              else
                begin
                  dest_fd.write(buffer)
                  dest_fd.flush
                rescue IOError
                  # Oops, the output fd was closed. Close the input end if not
                  # already done.
                  fd_map.delete(io)
                  safe_close_fd(io)
                end
              end
            end
          end

          # Close all FDs when closing. Expect that the programs we started
          # will stop once stdin is closed.
          (fd_map.keys + [serv]).each do |fd|
            close_read_fd(fd_map, fd)
          end
        end

        def close_read_fd(fd_map, fd)
          dest_fd = fd_map[fd]
          fd_map.delete(fd)

          # Close the FD, notify the other end that there won't be any more
          # traffic coming in.
          safe_close_fd(fd)
          safe_close_fd(dest_fd) unless dest_fd.nil? || dest_fd == @log_fd
        end

        def safe_close_fd(fd)
          fd.close
        # rubocop:disable Lint/HandleExceptions
        rescue IOError
          # Already closed. We don't care.
          # TODO: Check actual errno?
        end
        # rubocop:enable Lint/HandleExceptions
      end
    end
  end
end

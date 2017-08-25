module Aptible
  module CLI
    module Helpers
      module SecurityKey
        U2F_LOGGER = Logger.new(
          ENV['U2F_DEBUG'] ? STDERR : File.open(File::NULL, 'w')
        )

        class AuthenticatorParameters
          attr_reader :origin, :challenge, :app_id, :version, :key_handle
          attr_reader :request

          def initialize(origin, challenge, app_id, device)
            @origin = origin
            @challenge = challenge
            @app_id = app_id
            @version = device.version
            @key_handle = device.key_handle

            @request = {
              'challenge' => challenge,
              'appId' => app_id,
              'version' => version,
              'keyHandle' => key_handle
            }
          end
        end

        class ThrottledAuthenticator
          attr_reader :pid

          def initialize(auth, pid)
            @auth = auth
            @pid = pid
          end

          def exited(_status)
            [Authenticator.spawn(@auth), nil]
          end

          def self.spawn(auth)
            pid = Process.spawn(
              'sleep', '2',
              in: :close, out: :close, err: :close,
              close_others: true
            )

            U2F_LOGGER.debug("#{self} #{auth.key_handle}: spawned #{pid}")

            new(auth, pid)
          end
        end

        class Authenticator
          attr_reader :pid

          def initialize(auth, pid, out_read, err_read)
            @auth = auth
            @pid = pid
            @out_read = out_read
            @err_read = err_read
          end

          def exited(status)
            out, err = [@out_read, @err_read].map(&:read).map(&:chomp)

            if status.exitstatus == 0
              U2F_LOGGER.info("#{self.class} #{@auth.key_handle}: ok: #{out}")
              [nil, JSON.parse(out)]
            else
              U2F_LOGGER.warn("#{self.class} #{@auth.key_handle}: err: #{err}")
              [ThrottledAuthenticator.spawn(@auth), nil]
            end
          ensure
            [@out_read, @err_read].each(&:close)
          end

          def self.spawn(auth)
            in_read, in_write = IO.pipe
            out_read, out_write = IO.pipe
            err_read, err_write = IO.pipe

            pid = Process.spawn(
              'u2f-host', '-aauthenticate', '-o', auth.origin,
              in: in_read, out: out_write, err: err_write,
              close_others: true
            )

            U2F_LOGGER.debug("#{self} #{auth.key_handle}: spawned #{pid}")

            [in_read, out_write, err_write].each(&:close)

            in_write.write(auth.request.to_json)
            in_write.close

            new(auth, pid, out_read, err_read)
          end
        end

        class Device
          attr_reader :version, :key_handle

          def initialize(version, key_handle)
            @version = version
            @key_handle = key_handle
          end
        end

        def self.authenticate(origin, app_id, challenge, devices)
          procs = Hash[devices.map do |device|
            params = AuthenticatorParameters.new(
              origin, challenge, app_id, device
            )
            w = Authenticator.spawn(params)
            [w.pid, w]
          end]

          begin
            loop do
              pid, status = Process.wait2
              w = procs.delete(pid)
              raise "waited unknown pid: #{pid}" if w.nil?

              r, out = w.exited(status)

              procs[r.pid] = r if r
              return out if out
            end
          ensure
            procs.values.map(&:pid).each { |p| Process.kill(:SIGTERM, p) }
          end
        end
      end
    end
  end
end

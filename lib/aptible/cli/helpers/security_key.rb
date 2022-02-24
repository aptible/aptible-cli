require 'openssl'
require 'cbor'

module Aptible
  module CLI
    module Helpers
      module SecurityKey
        U2F_LOGGER = Logger.new(
          ENV['U2F_DEBUG'] ? STDERR : File.open(File::NULL, 'w')
        )

        class AuthenticatorParameters
          attr_reader :origin, :challenge, :app_id, :version, :key_handle
          attr_reader :request, :rp_id, :device_location
          attr_reader :client_data, :assert_str, :version

          def initialize(origin, challenge, app_id, device, device_location)
            @origin = origin
            @challenge = challenge
            @app_id = app_id
            @version = device.version
            @key_handle = device.key_handle
            @rp_id = device.rp_id
            @version = device.version
            @device_location = device_location
            @client_data = {
              type: 'webauthn.get',
              challenge: challenge,
              origin: origin,
              crossOrigin: false
            }.to_json
            key_handle = Base64.strict_encode64(
              Base64.urlsafe_decode64(device.key_handle)
            )
            client_data_hash = Digest::SHA256.base64digest(@client_data)
            in_str = "#{client_data_hash}\n" \
              "#{device.rp_id}\n" \
              "#{key_handle}"
            @assert_str = in_str
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

        class DeviceMapper
          attr_reader :pid

          def initialize(pid, out_read, err_read)
            @pid = pid
            @out_read = out_read
            @err_read = err_read
          end

          def exited(status)
            out, err = [@out_read, @err_read].map(&:read).map(&:chomp)

            if status.exitstatus == 0
              U2F_LOGGER.info("#{self.class}: ok: #{out}")
              [nil, out]
            else
              U2F_LOGGER.warn("#{self.class}: err: #{err}")
              [nil, nil]
            end
          ensure
            [@out_read, @err_read].each(&:close)
          end

          def self.spawn
            out_read, out_write = IO.pipe
            err_read, err_write = IO.pipe

            pid = Process.spawn(
              'fido2-token -L',
              out: out_write, err: err_write,
              close_others: true
            )

            U2F_LOGGER.debug("#{self}: spawned #{pid}")

            [out_write, err_write].each(&:close)

            new(pid, out_read, err_read)
          end
        end

        class Authenticator
          attr_reader :pid, :auth

          def initialize(auth, pid, out_read, err_read)
            @auth = auth
            @pid = pid
            @out_read = out_read
            @err_read = err_read
          end

          def formatted_out(out)
            arr = out.split("\n")
            authenticator_data = arr[2]
            signature = arr[3]
            appid = auth.app_id if auth.version == 'U2F_V2'
            client_data_json = Base64.urlsafe_encode64(auth.client_data)

            {
              id: auth.key_handle,
              rawId: auth.key_handle,
              clientExtensionResults: { appid: appid },
              type: 'public-key',
              response: {
                clientDataJSON: client_data_json,
                authenticatorData: Base64.urlsafe_encode64(
                  CBOR.decode(
                    Base64.strict_decode64(authenticator_data)
                  )
                ),
                signature: signature
              }
            }
          end

          def fido_err_msg(err)
            match = err.match(/(FIDO_ERR.+)/)
            return nil unless match
            result = match.captures || []
            no_cred = "\nCredential not found on device, " \
                      'are you sure you selected the right ' \
                      'credential for this device?'
            err_map = {
              'FIDO_ERR_NO_CREDENTIALS' => no_cred
            }

            return err_map[result[0]] if result.count > 0

            nil
          end

          def exited(status)
            out, err = [@out_read, @err_read].map(&:read).map(&:chomp)

            if status.exitstatus == 0
              U2F_LOGGER.info("#{self.class} #{@auth.key_handle}: ok: #{out}")
              [nil, out]
            else
              err_msg = fido_err_msg(err)
              CLI.logger.error(err_msg) if err_msg
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
              "fido2-assert -G #{auth.device_location}",
              in: in_read, out: out_write, err: err_write,
              close_others: true
            )

            U2F_LOGGER.debug("#{self} #{auth.key_handle}: spawned #{pid}")

            [in_read, out_write, err_write].each(&:close)

            in_write.write(auth.assert_str)
            in_write.close

            new(auth, pid, out_read, err_read)
          end
        end

        class Device
          attr_reader :version, :key_handle, :rp_id, :name

          def initialize(version, key_handle, name, rp_id)
            @version = version
            @key_handle = key_handle
            @name = name
            @rp_id = rp_id
          end
        end

        def self.device_locations
          w = DeviceMapper.spawn
          _, status = Process.wait2
          _, out = w.exited(status)
          # parse output and only log device
          matches = out.split("\n").map { |s| s.match(/^(\S+):\s/) }
          results = []
          matches.each do |m|
            capture = m.captures
            results << capture[0] if m && capture.count.positive?
          end

          results
        end

        def self.authenticate(origin, app_id, challenge,
                              device, device_locations)
          procs = Hash[device_locations.map do |location|
            params = AuthenticatorParameters.new(
              origin,
              challenge,
              app_id,
              device,
              location
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
              return w.formatted_out(out) if out
            end
          ensure
            procs.values.map(&:pid).each { |p| Process.kill(:SIGTERM, p) }
          end
        end
      end
    end
  end
end

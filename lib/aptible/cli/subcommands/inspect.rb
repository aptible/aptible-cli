module Aptible
  module CLI
    module Subcommands
      module Inspect
        class InspectResourceCommand < Thor::HiddenCommand
          def run(instance, args = [])
            instance.inspect_resource(*args)
          end
        end

        def inspect_resource(raw)
          begin
            uri = URI(raw)
          rescue URI::InvalidURIError
            raise Thor::Error, "Invalid URI: #{raw}"
          end

          if uri.scheme != 'https'
            raise "Invalid scheme: #{uri.scheme} (use https)"
          end

          apis = [Aptible::Auth, Aptible::Api, Aptible::Billing]

          api = apis.find do |klass|
            uri.host == URI(klass.configuration.root_url).host
          end

          if api.nil?
            hosts = apis.map(&:configuration).map(&:root_url).map do |u|
              URI(u).host
            end
            m = "Invalid API: #{uri.host} (valid APIs: #{hosts.join(', ')})"
            raise Thor::Error, m
          end

          res = api::Resource.new(token: fetch_token).find_by_url(uri.to_s)
          puts JSON.pretty_generate(res.body)
        end

        def self.included(thor)
          # We have to manually register a command here since we can't override
          # the inspect method!
          desc = 'Inspect a resource as JSON by URL'
          thor.commands['inspect'] = InspectResourceCommand.new(
            :inspect, desc, desc, 'inspect URL'
          )
        end
      end
    end
  end
end

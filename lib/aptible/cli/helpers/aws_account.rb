require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module AwsAccount
        include Helpers::Token

        def aws_accounts_href
          href = '/external_aws_accounts'
          if Renderer.format != 'json'
            href = '/external_aws_accounts?per_page=5000&no_embed=true'
          end
          href
        end

        def aws_accounts_all
          Aptible::Api::ExternalAwsAccount.all(
            token: fetch_token,
            href: aws_accounts_href
          )
        end

        def aws_account_from_id(id)
          Aptible::Api::ExternalAwsAccount.all(token: fetch_token).find do |a|
            a.id.to_s == id.to_s
          end
        end

        def ensure_external_aws_account(id)
          acct = aws_account_from_id(id)
          raise Thor::Error, "External AWS account not found: #{id}" if acct.nil?
          acct
        end

        def build_external_aws_account_attrs(options)
          role_arn = options[:role_arn] || options[:arn]
          attrs = {
            role_arn: role_arn,
            account_name: options[:account_name] || options[:name],
            aws_account_id: options[:aws_account_id],
            aws_region_primary: options[:aws_region_primary],
            status: options[:status],
            discovery_enabled: options.key?(:discovery_enabled) ? options[:discovery_enabled] : nil,
            discovery_frequency: options[:discovery_frequency]
          }
          attrs.reject { |_, v| v.nil? }
        end

        def create_external_aws_account!(options)
          attrs = build_external_aws_account_attrs(options)
          Aptible::Api::ExternalAwsAccount.create(
            token: fetch_token,
            **attrs
          )
        end

        def update_external_aws_account!(id, options)
          ext = ensure_external_aws_account(id)
          attrs = build_external_aws_account_attrs(options)
          ext.update!(**attrs) unless attrs.empty?
          ext
        end

        def delete_external_aws_account!(id)
          ext = ensure_external_aws_account(id)
          if ext.respond_to?(:destroy!)
            ext.destroy!
          elsif ext.respond_to?(:destroy)
            ext.destroy
          elsif ext.respond_to?(:delete!)
            ext.delete!
          elsif ext.respond_to?(:delete)
            ext.delete
          else
            raise Thor::Error, 'Delete is not supported for this resource'
          end
          true
        end
      end
    end
  end
end



# frozen_string_literal: true

require 'aptible/api'

module Aptible
  module CLI
    module Helpers
      module AwsAccount
        include Helpers::Token

        def aws_accounts_href
          if Renderer.format == 'json'
            '/external_aws_accounts'
          else
            '/external_aws_accounts?per_page=5000&no_embed=true'
          end
        end

        def aws_accounts_all
          Aptible::Api::ExternalAwsAccount.all(
            token: fetch_token,
            href: aws_accounts_href
          )
        end

        def aws_account_from_id(id)
          Aptible::Api::ExternalAwsAccount.find(id.to_s, token: fetch_token)
        end

        def ensure_external_aws_account(id)
          acct = aws_account_from_id(id)
          if acct.nil?
            raise Thor::Error, "External AWS account not found: #{id}"
          end

          acct
        end

        def fetch_organization_id
          orgs = Aptible::Auth::Organization.all(token: fetch_token)
          raise Thor::Error, 'No organizations found, specify one with ' \
                             '--organization-id=ORG_ID' if orgs.empty?
          raise Thor::Error, 'Multiple organizations found, indicate which ' \
                             'one to use with --organization-id=ORG_ID ' \
                             "\n\tFound organization ids:" \
                             "\n\t\t#{orgs.map do |o|
                               "#{o.id} (#{o.name})"
                             end.join("\n\t\t")}" \
                             if orgs.count > 1

          orgs.first.id
        end

        def organization_id_from_opts_or_auth(options)
          return options[:organization_id] if options.key? :organization_id

          fetch_organization_id
        end

        def build_external_aws_account_attrs(options)
          discovery_role_arn = if options[:remove_discovery_role_arn]
                                 ''
                               else
                                 options[:discovery_role_arn]
                               end
          discovery_enabled = if options.key?(:discovery_enabled)
                                options[:discovery_enabled]
                              end
          attrs = {
            account_name: options[:account_name] || options[:name],
            aws_account_id: options[:aws_account_id],
            aws_region_primary: options[:aws_region_primary],
            status: options[:status],
            discovery_enabled: discovery_enabled,
            discovery_role_arn: discovery_role_arn,
            discovery_frequency: options[:discovery_frequency]
          }
          attrs.reject { |_, v| v.nil? }
        end

        def create_external_aws_account!(options)
          attrs = build_external_aws_account_attrs(options)
          attrs[:organization_id] = organization_id_from_opts_or_auth(options)
          begin
            resource = Aptible::Api::ExternalAwsAccount.create(
              token: fetch_token,
              **attrs
            )
            if resource.errors.any?
              raise Thor::Error, resource.errors.full_messages.first
            end
            resource
          rescue HyperResource::ClientError => e
            raise Thor::Error, e.message
          end
        end

        def update_external_aws_account!(id, options)
          ext = ensure_external_aws_account(id)
          attrs = build_external_aws_account_attrs(options)
          begin
            unless attrs.empty?
              ext.update!(**attrs)
              if ext.errors.any?
                raise Thor::Error, ext.errors.full_messages.first
              end
            end
            ext
          rescue HyperResource::ClientError => e
            raise Thor::Error, e.message
          end
        end

        def delete_external_aws_account!(id)
          ext = ensure_external_aws_account(id)
          begin
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
          rescue HyperResource::ClientError => e
            raise Thor::Error, e.message
          end
          true
        end

        def check_external_aws_account!(id)
          ext = ensure_external_aws_account(id)
          begin
            ext.check!
          rescue HyperResource::ClientError => e
            raise Thor::Error, e.message
          end
        end

        def format_check_state(state)
          case state
          when 'success'
            '✅ success'
          when 'failed'
            '❌ failed'
          when 'not_run'
            '⏭️  not_run'
          else
            state
          end
        end
      end
    end
  end
end

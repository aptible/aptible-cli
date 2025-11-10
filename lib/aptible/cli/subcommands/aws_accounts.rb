module Aptible
  module CLI
    module Subcommands
      module AwsAccounts
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::AwsAccount
            include Helpers::Telemetry

            desc 'aws_accounts', 'List external AWS accounts'
            def aws_accounts
              telemetry(__method__, options)

              accounts = aws_accounts_all

              Formatter.render(Renderer.current) do |root|
                root.list do |list|
                  accounts.each do |ext|
                    list.object do |node|
                      # Always include id when available
                      node.value('id', ext.id) if ext.respond_to?(:id)

                      # Include a few likely attributes if present
                      attrs = ext.respond_to?(:attributes) ? ext.attributes : {}
                      %w[
                        aws_account_id
                        account_name
                        aws_region_primary
                        status
                        discovery_enabled
                        discovery_frequency
                        role_arn
                        account_id
                        created_at
                        updated_at
                      ].each do |k|
                        v = attrs[k]
                        node.value(k, v) unless v.nil?
                      end
                    end
                  end
                end
              end
            end

            desc 'aws_accounts:add ' \
                 '[--role-arn ROLE_ARN] ' \
                 '[--account-name ACCOUNT_NAME] ' \
                 '[--aws-account-id AWS_ACCOUNT_ID] ' \
                 '[--organization-id ORG_ID] ' \
                 '[--aws-region-primary AWS_REGION] ' \
                 '[--discovery-enabled|--no-discovery-enabled] ' \
                 '[--discovery-frequency FREQ]', \
                 'Add a new external AWS account'
            option :role_arn, type: :string, desc: 'IAM Role ARN to assume'
            option :account_name, type: :string, desc: 'Display name'
            option :aws_account_id, type: :string, desc: 'AWS Account ID'
            option :organization_id, type: :string, desc: 'Organization ID'
            option :aws_region_primary, type: :string, desc: 'Primary AWS region'
            option :discovery_enabled, type: :boolean, desc: 'Enable resource discovery'
            option :discovery_frequency, type: :string, desc: 'Discovery frequency (e.g., daily)'
            define_method 'aws_accounts:add' do
              telemetry(__method__, options)

              resource = create_external_aws_account!(options)

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  node.value('id', resource.id) if resource.respond_to?(:id)
                  rattrs = resource.respond_to?(:attributes) ? resource.attributes : {}
                  %w[
                    aws_account_id
                    account_name
                    aws_region_primary
                    discovery_enabled
                    discovery_frequency
                    role_arn
                    account_id
                    created_at
                    updated_at
                  ].each do |k|
                    v = rattrs[k]
                    node.value(k, v) unless v.nil?
                  end
                end
              end
            end

            desc 'aws_accounts:delete ID', 'Delete an external AWS account'
            define_method 'aws_accounts:delete' do |id|
              telemetry(__method__, options.merge(id: id))

              delete_external_aws_account!(id)

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  node.value('id', id)
                  node.value('deleted', true)
                end
              end
            end

            desc 'aws_accounts:update ID [--role-arn ROLE_ARN] ' \
                 '[--account-name ACCOUNT_NAME] ' \
                 '[--aws-account-id AWS_ACCOUNT_ID] ' \
                 '[--organization-id ORG_ID] ' \
                 '[--aws-region-primary AWS_REGION] ' \
                 '[--discovery-enabled|--no-discovery-enabled] ' \
                 '[--discovery-frequency FREQ]', \
                 'Update an external AWS account'
            option :role_arn, type: :string, desc: 'New IAM Role ARN to assume'
            option :account_name, type: :string, desc: 'New display name'
            option :aws_account_id, type: :string, desc: 'AWS Account ID'
            option :organization_id, type: :string, desc: 'Organization ID'
            option :aws_region_primary, type: :string, desc: 'Primary AWS region'
            option :discovery_enabled, type: :boolean, desc: 'Enable resource discovery'
            option :discovery_frequency, type: :string, desc: 'Discovery frequency (e.g., daily)'
            define_method 'aws_accounts:update' do |id|
              telemetry(__method__, options.merge(id: id))

              ext = update_external_aws_account!(id, options)

              Formatter.render(Renderer.current) do |root|
                root.object do |node|
                  node.value('id', ext.id)
                  rattrs = ext.respond_to?(:attributes) ? ext.attributes : {}
                  %w[
                    aws_account_id
                    account_name
                    aws_region_primary
                    discovery_enabled
                    discovery_frequency
                    role_arn
                    account_id
                    created_at
                    updated_at
                  ].each do |k|
                    v = rattrs[k]
                    node.value(k, v) unless v.nil?
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end




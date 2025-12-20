# frozen_string_literal: true

module Aptible
  module CLI
    module Subcommands
      module Organizations
        def self.included(thor)
          thor.class_eval do
            include Helpers::Token
            include Helpers::Telemetry

            desc 'organizations', 'List all organizations'
            option :with_organization_role,
                   aliases: '--with-org-role',
                   type: :boolean,
                   default: false,
                   desc: 'Include your role in each organization ' \
                         '(requires additional API calls)'
            def organizations
              telemetry(__method__, options)

              token = fetch_token
              orgs = Aptible::Auth::Organization.all(token: token)

              user_roles_by_org = {}
              if options[:with_organization_role]
                user = Aptible::Auth::User.all(token: token).first
                user.roles.each do |role|
                  begin
                    org = role.organization
                  rescue StandardError
                    next
                  end
                  next unless org

                  org_id = org.id
                  role_name = begin
                                role.name
                              rescue StandardError
                                'unnamed'
                              end

                  user_roles_by_org[org_id] ||= []
                  user_roles_by_org[org_id] << role_name
                end
              end

              Formatter.render(Renderer.current) do |root|
                root.list do |list|
                  orgs.each do |org|
                    list.object do |node|
                      node.value('id', org.id)
                      node.value('name', org.name)
                      if org.respond_to?(:handle) && org.handle
                        node.value('handle', org.handle)
                      end
                      if options[:with_organization_role]
                        roles = user_roles_by_org[org.id] || []
                        node.value('role', roles.join(', '))
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
  end
end

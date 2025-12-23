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
            def organizations
              telemetry(__method__, options)

              user = Aptible::Auth::Token.current_token(token: fetch_token).user
              user_orgs_and_roles = {}
              user.roles_with_organizations.each do |role|
                user_orgs_and_roles[role.organization.id] ||= {
                  'org' => role.organization,
                  'roles' => []
                }
                user_orgs_and_roles[role.organization.id]['roles'] << role
              end
              Formatter.render(Renderer.current) do |root|
                root.list do |list|
                  user_orgs_and_roles.each do |org_id, org_and_role|
                    org = org_and_role['org']
                    roles = org_and_role['roles']
                    list.object do |node|
                      node.value('id', org.id)
                      node.value('name', org.name)
                      node.list('roles') do |roles_list|
                        roles.each do |role|
                          roles_list.object do |role_node|
                            role_node.value('id', role.id)
                            role_node.value('name', role.name)
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
  end
end

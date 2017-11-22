module Aptible
  module CLI
    module Formatter
      class GroupedKeyedList < KeyedList
        attr_reader :group

        class InvalidGroup
          def initialize(group)
            m = 'group argument must be a string or a hash with one key ' \
                "and a string value. #{group} is invalid"
            super(m)
          end
        end

        def initialize(group, y)
          @group = group
          validate_group!
          super(y)
        end

        def groups
          children.group_by(&grouper)
        end

        private

        def grouper
          case group
          when String
            lambda do |n|
              n.children.fetch(group)
            end
          when Hash
            first, second = group.to_a.first
            lambda do |n|
              n.children.fetch(first).children.fetch(second)
            end
          end
        end

        def validate_group!
          return if group.is_a?(String)
          if group.is_a?(Hash)
            keys = group.keys
            raise InvalidGroup, group if keys.size != 1
            raise InvalidGroup, group unless group[keys.first].is_a?(String)
            return
          end
          raise InvalidGroup(group)
        end
      end
    end
  end
end

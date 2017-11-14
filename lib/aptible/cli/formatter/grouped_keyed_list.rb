module Aptible
  module CLI
    module Formatter
      class GroupedKeyedList < KeyedList
        attr_reader :group

        def initialize(group, y)
          @group = group
          super(y)
        end
      end
    end
  end
end

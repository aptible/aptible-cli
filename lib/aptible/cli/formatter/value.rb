module Aptible
  module CLI
    module Formatter
      class Value < Node
        include Comparable

        attr_reader :value

        def initialize(value)
          @value = value
        end

        def <=>(other)
          value <=> other.value
        end

        alias eql? ==

        def hash
          value.hash
        end
      end
    end
  end
end

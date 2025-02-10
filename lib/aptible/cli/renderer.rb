require 'json'

require_relative 'renderer/base'
require_relative 'renderer/json'
require_relative 'renderer/text'

module Aptible
  module CLI
    module Renderer
      FORMAT_VAR = 'APTIBLE_OUTPUT_FORMAT'.freeze

      def self.format
        ENV[FORMAT_VAR]
      end

      def self.current
        case format
        when 'json'
          Json.new
        when 'text'
          Text.new
        when nil
          Text.new
        else
          raise UserError, "Invalid #{FORMAT_VAR}: #{format}"
        end
      end
    end
  end
end

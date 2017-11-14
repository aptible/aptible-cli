require 'logger'

require 'aptible/cli/version'
require 'aptible/cli/agent'
require 'aptible/cli/error'
require 'aptible/cli/formatter'
require 'aptible/cli/renderer'

module Aptible
  module CLI
    class LogFormatter
      include Term::ANSIColor

      def call(severity, _, _, msg)
        color = case severity
                when 'DEBUG'
                  :no_color
                when 'INFO'
                  :green
                when 'WARN'
                  :yellow
                when 'ERROR', 'FATAL'
                  :red
                else
                  :no_color
                end

        "#{public_send(color, msg)}\n"
      end

      def no_color(msg)
        msg
      end
    end

    def self.logger
      @logger ||= Logger.new($stderr).tap do |l|
        l.formatter = LogFormatter.new
      end
    end
  end
end

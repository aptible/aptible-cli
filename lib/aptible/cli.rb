require 'logger'

require 'aptible/cli/version'
require 'aptible/cli/agent'
require 'aptible/cli/error'
require 'aptible/cli/formatter'
require 'aptible/cli/renderer'
require 'aptible/cli/resource_formatter'

module Aptible
  module CLI
    class TtyLogFormatter
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

    class PlainLogFormatter
      def call(_, _, _, msg)
        "#{msg}\n"
      end
    end

    def self.logger
      formatter_klass = if $stderr.tty?
                          TtyLogFormatter
                        else
                          PlainLogFormatter
                        end

      @logger ||= Logger.new($stderr).tap do |l|
        l.formatter = formatter_klass.new
      end
    end
  end
end

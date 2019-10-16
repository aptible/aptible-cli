module Aptible
  module CLI
    module Helpers
      module System
        def which(cmd)
          exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']

          ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
            exts.each do |ext|
              exe = File.join(path, "#{cmd}#{ext}")
              return exe if File.executable?(exe) && !File.directory?(exe)
            end
          end

          nil
        end

        def ask_then_line(*args)
          ret = ask(*args)
          puts ''
          ret
        end
      end
    end
  end
end

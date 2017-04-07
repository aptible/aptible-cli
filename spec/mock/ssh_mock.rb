#!/usr/bin/env ruby
require 'json'

raise 'Something went wrong!' if ENV['SSH_MOCK_FAIL_TUNNEL']

# Log arguments to SSH_MOCK_OUTFILE
File.open(ENV.fetch('SSH_MOCK_OUTFILE'), 'w') do |f|
  f.write({
    'pid' => $PID,
    'argc' => ARGV.size,
    'argv' => ARGV,
    'env' => ENV.to_hash
  }.to_json)
end

puts 'TUNNEL READY'

exit Integer(ENV.fetch('SSH_MOCK_EXITCODE', 0))

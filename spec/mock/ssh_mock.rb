#!/usr/bin/env ruby
require 'json'

fail 'Something went wrong!' if ENV['FAIL_TUNNEL']

# Log arguments to SSH_MOCK_OUTFILE
File.open(ENV.fetch('SSH_MOCK_OUTFILE'), 'w') do |f|
  f.write({
    'argc' => ARGV.size,
    'argv' => ARGV,
    'env' => ENV.to_hash
  }.to_json)
end

puts 'TUNNEL READY'

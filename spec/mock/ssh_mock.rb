#!/usr/bin/env ruby

# Emulate server behavior

if ENV['TUNNEL_PORT']
  fail 'Something went wrong!' if ENV['FAIL_TUNNEL']
  puts 'TUNNEL READY'
else
  fail 'Something went wrong!' if ENV['FAIL_PORT']
  puts 1234
end

# Log to SSH_MOCK_OUTFILE
require 'json'

File.open(ENV.fetch('SSH_MOCK_OUTFILE'), 'w') do |f|
  f.write({
    'argc' => ARGV.size,
    'argv' => ARGV,
    'env' => ENV.to_hash
  }.to_json)
end

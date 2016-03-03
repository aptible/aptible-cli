#!/usr/bin/env ruby

# Emulate server behavior

if ENV['TUNNEL_PORT']
  fail 'Something went wrong!' if ENV['FAIL_TUNNEL']
  puts 'TUNNEL READY'
else
  fail 'Something went wrong!' if ENV['FAIL_PORT']
  puts 1234
end

# Log to stderr so we can collect in test

$stderr.puts ARGV.size
ARGV.each do |a|
  $stderr.puts a
end

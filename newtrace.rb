#!/usr/bin/ruby1.8
require 'lib/newtrace'

def format_times t
  if !t
    "? ms  ? ms  ? ms"
  else
    (t.map { |time| sprintf "%.2f ms", time }).join("  ")
  end
end

def show_usage
  puts "Usage:"
  puts "  ./newtrace.rb [-n] [-t TIMEOUT] [-m MASK] [-r RETRIES] host"
  puts "Options:"
  puts "  -h          This help."
  puts "  -n          Do not resolve IP addresses to their domain names."
  puts "  -t TIMEOUT  Set timeout in ms (default: 400)."
  puts "  -m MASK     Set minimal mask for outgoing interface scanning (default: 28)."
  puts "  -r RETRIES  How many ICMP packets send."
  puts "Arguments:"
  puts "  host        The host to traceroute to."
  exit
end

if ARGV.length < 1 or ARGV.index('-h')
  show_usage
end

unless Process.uid == 0
  puts 'Must run as root.'
  exit
end

trap('INT') do
  puts "You've pressed ^C"
  exit
end

host = Ip.new(ARGV.last)
if host.empty?
  puts "Invalid hostname #{ARGV.last}"
  exit
end

timeout = 400
min_mask = 28
retries = 3

resolv = !ARGV.index('-n')
timeout = ARGV[ARGV.index('-t') + 1].to_i if ARGV.index('-t')
min_mask = ARGV[ARGV.index('-m') + 1].to_i if ARGV.index('-m')
retries = ARGV[ARGV.index('-r') + 1].to_i if ARGV.index('-r')

newtrace = Newtrace.new(host, {:timeout => timeout, :min_mask => min_mask, :retries => retries, :resolv => resolv})
newtrace.each_router(true) do |r|
  if r[:second_if]
    puts "/#{r[:second_if].to_s(resolv)}  #{format_times(r[:times])}"
  else
    puts "  #{format_times(r[:times])}"
  end
end

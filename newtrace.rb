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
  puts "  -t TIMEOUT  Set timeout in ms (default: #{@options[:timeout]})."
  puts "  -m MASK     Set minimal mask for outgoing interface scanning (default: #{@options[:min_mask]})."
  puts "  -r RETRIES  How many ICMP packets send (default: #{@options[:retries]}."
  puts "Arguments:"
  puts "  host        The host to traceroute to."
  exit
end

unless Process.uid == 0
  puts 'newtrace must be run as root user.'
  exit
end

trap('INT') do
  puts "You've pressed ^C"
  exit
end

# default settings
@options = { :timeout => 400,
             :min_mask => 28,
             :retries => 3,
             :resolv => true}

# parameters with value
{:timeout => '-t', :min_mask => '-m', :retries => '-r'}.each do |n, v|
  @options[n] = ARGV[ARGV.index(v) + 1].to_i if ARGV.index(v)
end

# parameters without value
{:resolv => '!-n', :help => '-h'}.each do |n, v|
  if v[0..0] == '!'
    @options[n] = !ARGV.index(v[1..-1])
  else
    @options[n] = ARGV.index(v)
  end
end

show_usage if ARGV.length < 1 or @options[:help]

host = Ip.new(ARGV.last)
if host.empty?
  puts "Invalid hostname #{ARGV.last}"
  exit
end

newtrace = Newtrace.new(host, @options)
newtrace.each_router(true) do |r|
  if r[:second_if]
    puts "/#{r[:second_if].to_s(@options[:resolv])}  #{format_times(r[:times])}"
  else
    puts "  #{format_times(r[:times])}"
  end
end

#!/usr/bin/ruby1.8
require 'lib/newtrace'

def format_times t
  if !t
    "* * *"
  else
    s = t.map do |time|
      if time
        sprintf("%.2f ms", time)
      else
        "*"
      end
    end
    s.join("  ")
  end
end

def show_usage
  puts "Usage:"
  puts "  ./newtrace.rb [-h] [-n] [-M MASK] [-m MAX_TTL] [-q NQUERIES] [-c] [-i]
                [-w TIMEOUT] host"
  puts "Options:"
  puts "  -h          This help"
  puts "  -n          Do not resolve IP addresses to their domain names"
  puts "  -M MASK     Set minimal mask for outgoing interface scanning (default: #{@options[:min_mask]})"
  puts "  -m MAX_TTL  Set the max number of hops (max TTL to be reached). Default is #{@options[:max_ttl]}"
  puts "  -q NQUERIES Set the number of probes per each hop. Default #{@options[:retries]}"
  puts "  -c          Do not use TTL comparing"
  puts "  -i          Do not use identifier field comparing"
  puts "  -w TIMEOUT  Set the number of seconds to wait for response to a probe (default
              is #{@options[:timeout]}). Non-integer (float point) values allowed too"

  puts "Arguments:"
  puts "  host        The host to traceroute to"
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
@options = { :timeout => 0.5,
             :min_mask => 28,
             :retries => 3,
             :resolv => true,
             :ident_compare => true,
             :ttl_compare => true,
             :max_ttl => 30
           }

# parameters with value
{:timeout => '-w', :min_mask => '-M', :retries => '-q', :max_ttl => '-m'}.each do |n, v|
  next unless ARGV.index(v)
  c = @options[n].class
  @options[n] = ARGV[ARGV.index(v) + 1]
  if c == Float
    @options[n] = @options[n].to_f
  elsif c == Fixnum
    @options[n] = @options[n].to_i
  end
end

# parameters without value
{:resolv => '!-n', :help => '-h', :ident_compare => '!-i', :ttl_compare => '!-c'}.each do |n, v|
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
puts "traceroute to #{host.to_s true} (#{host.to_s}), #{@options[:max_ttl]} hops max"
newtrace.each_router(true) do |r|
  if r[:second_if]
    puts "/#{r[:second_if].to_s(@options[:resolv])}  #{format_times(r[:times])}"
  else
    puts "  #{format_times(r[:times])}"
  end
end

require 'lib/icmpping'
require 'lib/mask'
require 'lib/ip'

class Newtrace
  def initialize host, options = {}
    if host.class == Ip
      @ip = host
    else
      @ip = Ip.new(host)
    end
    @options = options
  end

  def each_router print = false
    1.upto(@options[:max_ttl]) do |ttl|
      pair = find_pair ttl, print
      if pair[:to].empty?
        yield({:ttl => ttl, :first_if => pair[:from], :times => pair[:times]})
      else
        yield({:ttl => ttl, :first_if => pair[:from], :second_if => pair[:to], :times => pair[:times]})
      end
      break if pair[0] == @ip
      break if pair[:finished]
    end
  end

  def find_pair ttl, print = false
    res = nil
    res2 = nil
    sec_if = nil
    finished = false
    printed = false
    0.upto(3) do
      if !res or !res[:host]
        res = ICMPPing.ping(@ip, ttl, @options[:timeout], @options[:retries])
      end
      next if !res[:host]
      if !printed and print
        print "#{ttl.to_s.rjust(2)}  #{Ip.from_raw(res[:host]).to_s(@options[:resolv])}"
        STDOUT.flush
        printed = true
      end
      finished = true and break if res[:type] == :echo_reply or res[:type] == :echo_request # self-traceroute

      res2 = ICMPPing.ping(@ip, ttl + 1, @options[:timeout], 1)
      next if !res2[:host]
      break if res2[:type] == :echo_reply # final host

      sec_if = find_second_interface(Ip.from_raw(res2[:host]), Ip.from_raw(res[:host]), ttl)
      break
    end
    print "#{ttl.to_s.rjust(2)}  " if !printed
    pair = {:from => Ip.new, :to => Ip.new, :finished => finished}
    pair[:times] = res[:times] if res
    pair[:from] = Ip.from_raw(res[:host]) if res[:host]
    if sec_if
      pair[:to] = sec_if
    elsif res2 and res2[:host]
      pair[:to] = Ip.from_raw(res2[:host])
    end
    pair
  end

  private
  def find_second_interface same_subnet_ip, same_router_ip, ttl
    tested = []
    30.downto(@options[:min_mask]) do |bit_mask|
      mask = Mask.new(bit_mask)
      mask.each_ip(same_subnet_ip) do |i|
        next if tested.index(i)
        res = ICMPPing.ping(i, ttl, @options[:timeout], 1)
        tested << i
        next if res[:type] != :echo_reply
        next if ttl > 1 and is_closer_than_n ttl, i
        next if @options[:ttl_compare] and !compare_ttl same_router_ip, i
        next if @options[:ident_compare] and !compare_ident same_router_ip, i
        return i
      end
    end
    Ip.new
  end

  def is_closer_than_n n, ip
    res = ICMPPing.ping(ip, n-1, @options[:timeout], 1)
    res[:type] == :echo_reply
  end

  def compare_ttl ip1, ip2
    res1 = ICMPPing.ping(ip1, 64, @options[:timeout], 1)
    res2 = ICMPPing.ping(ip2, 64, @options[:timeout], 1)
    return true if !res1[:ttl] or !res2[:ttl]
    res1[:ttl] == res2[:ttl]
  end

  def compare_ident ip1, ip2
    res1 = ICMPPing.ping(ip1, 64, @options[:timeout], 1)
    res2 = ICMPPing.ping(ip2, 64, @options[:timeout], 1)
    return true if !res1[:ident] or !res2[:ident]
    (res1[:ident] - res2[:ident]).abs < 10
  end
end

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
    @options = {}
    @options[:min_mask] = 28
    @options[:timeout] = 500
    @options[:retries] = 3
    @options.merge!(options)
  end

  def each_router print = false
    ttl = 1
    begin
      pair = find_pair ttl, print
      if pair[:to].empty?
        yield({:ttl => ttl, :first_if => pair[:from], :times => pair[:times]})
      else
        yield({:ttl => ttl, :first_if => pair[:from], :second_if => pair[:to], :times => pair[:times]})
      end
      break if pair[0] == @ip
      ttl += 1
    end while !pair[:finished]
  end

  def find_pair ttl, print = false
    res = nil
    res2 = nil
    sec_if = nil
    finished = false
    printed = false
    0.upto(3) do
      if !res or res.length == 0
        res = ICMPPing.ping(@ip, ttl, @options[:timeout], @options[:retries])
      end
      next if !res or res.length == 0
      if !printed and print
        print "#{ttl} #{Ip.from_raw(res[:host]).to_s(@options[:resolv])}"
        STDOUT.flush
        printed = true
      end
      finished = true and break if res[:type] == :echo_reply

      res2 = ICMPPing.ping(@ip, ttl + 1, @options[:timeout], 1)
      next if !res2 or res2.length == 0
      break if res2[:type] == :echo_reply # final host

      sec_if = find_second_interface(Ip.from_raw(res2[:host]), ttl)
      break
    end
    pair = {:from => Ip.new, :to => Ip.new, :finished => finished}
    pair[:times] = res[:times] if res
    pair[:from] = Ip.from_raw(res[:host]) if res.length > 0
    if sec_if
      pair[:to] = sec_if
    elsif res2 and res2.length > 0
      pair[:to] = Ip.from_raw(res2[:host])
    end
    pair
  end

  private
  def find_second_interface ip, ttl
    tested = []
    30.downto(@options[:min_mask]) do |bit_mask|
      mask = Mask.new(bit_mask)
      mask.each_ip(ip) do |i|
        next if tested.index(i)
        res = ICMPPing.ping(i, ttl, @options[:timeout], 1)
        return i if res[:type] == :echo_reply
        tested << i
      end
    end
    Ip.new
  end
end

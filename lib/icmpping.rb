# Modified version of http://raa.ruby-lang.org/project/icmpping/ by arton
# GPL licensed

require 'socket'
require 'timeout'

module ICMPPing
  DEF_PACKET_SIZE = 64
  MAX_PACKET_SIZE = 1024
 private
  def ping(*args) ICMPPing.ping(*args) end
end

class << ICMPPing
  IPPROTO_ICMP = 1
  ICMP_ECHO = 8
  ICMP_TYPES = {0 => :echo_reply, 3 => :destination_unreachable, 4 => :source_quench, 5 => :redirect_message, 8 => :echo_request, 9 => :router_adv, 10 => :router_solicitation, 11 => :time_exceeded, 12 => :parameter_problem, 13 => :timestamp, 14 => :timestamp_reply, 15 => :infomration_request, 16 => :information_reply, 17 => :address_mask_request, 18 => :address_mask_reply, 30 => :traceroute}

  def ping(host, ttl = 64, timeout = 50, retries = 3, dlen = self::DEF_PACKET_SIZE)
    return -3 if dlen > self::MAX_PACKET_SIZE
    dest = host.to_raw
    begin
      hp = [Socket::AF_INET, 0, dest, 0, 0]
    rescue
      $stderr.printf($!.message + "\n") if $VERBOSE
      return -1
    end

    s = Socket.new(Socket::AF_INET, Socket::SOCK_RAW, IPPROTO_ICMP)
    s.setsockopt(Socket::IPPROTO_IP, Socket::IP_TTL, [ttl].pack('i'))

    start = tick
    id = $$ & 0xffff
    icmph = [ ICMP_ECHO, 0, 0, id, 0, start.to_i & 0xffffffff, nil ]
    icmph[6] = "E" * dlen
    dat = icmph.pack("C2n3Na*")
    cksum = checksum(((dat.length & 1) ? (dat + "\0") : dat).unpack("n*"))
    dat[2], dat[3] = cksum >> 8, cksum & 0xff
    begin
      type = nil
      rhost = nil
      times = []
      0.upto(retries-1) do
        _start = Time.now
        s.send dat, 0, hp.pack("v2a*N2")
        timeout(timeout / 1000.0) do
          rdat = s.recvfrom(self::MAX_PACKET_SIZE + 500)
          _stop = Time.now
          rhost = rdat[1].unpack("v2a4")[2]
          icmpdat = rdat[0].slice((rdat[0][0] & 0x0f) * 4..-1)
          resp = icmpdat.unpack("C2n3N")
          type = resp[0]
          type = ICMP_TYPES[resp[0]] if ICMP_TYPES[resp[0]]
          times << (_stop - _start) * 1000
        end
      end
      return :type => type, :host => rhost, :times => times
    rescue TimeoutError
      return {}
    end
    {}
  end

 private
  def tick
    Time.now.to_f * 1000
  end

  def checksum(n)
    ck = 0
    n.each do |v|
      ck += v
    end
    ck = (ck >> 16) + (ck & 0xffff)
    ck += ck >> 16
    ~ck
  end
end

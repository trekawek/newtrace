require 'timeout'

class Ip
  attr_accessor :ip

  def initialize host = nil
    if host == nil
      @ip = [0,0,0,0]
      return
    elsif host.class == Array
      @ip = host.map { |o| o.to_i }
      return
    elsif host =~ /^\d.\d.\d.\d$/
      @ip = host
    else
      begin
        @ip = TCPSocket.getaddress(host)
      rescue
        @ip = [0,0,0,0]
        return
      end
    end
    @ip = @ip.split('.').map { |o| o.to_i }
  end

  def self.from_raw host
    Ip.new(host.split('').map { |o| o[0].to_s })
  end

  def to_raw
    dest = ''
    @ip.each do |byte| 
      dest += byte.to_i.chr
    end
    dest
  end

  def to_s resolv = false
    if resolv
      begin
        timeout(0.5) { return Socket.getaddrinfo(@ip.join('.'), nil)[0][2] }
      rescue TimeoutError
        return to_s(false)
      end
    else
      @ip.join('.')
    end
  end

  def next!
    @ip = self.next.ip
    self
  end

  def next
    ip = @ip.clone
    ip[3] += 1
    if ip[3] == 256
      ip[3] = 0
      ip[2] += 1
    end
    if ip[2] == 256
      ip[2] = 0
      ip[1] += 1
    end
    if ip[1] == 256
      ip[1] = 0
      ip[0] += 1
    end
    ip[0] = 0 if ip[0] == 256
    Ip.new(ip)
  end
  
  def [] i
    @ip[i]
  end

  def []= i, v
    @ip[i] = v
  end

  def == v
    return false if v.class != self.class
    0.upto(3) { |i| return false if v[i] != @ip[i] }
    true
  end

  def empty?
    @ip == [0,0,0,0]
  end
end

class Mask
  def initialize bits
    @mask = "0" * 32
    0.upto(bits - 1) { |i| @mask[i] = '1' }
    @mask = @mask.scan(/[01]{8}/).map { |o| o.to_i(2) }
  end

  def each_ip ip
    i = network(ip)
    to = broadcast(ip)
    while i.next! != to
      yield Ip.new(i.ip)
    end
  end

  def network ip
    network = []
    0.upto(3) { |i| network << (@mask[i] & ip[i]) }
    Ip.new(network)
  end
  
  def broadcast ip
    broadcast = network(ip).ip
    0.upto(3) { |i| broadcast[i] |= (@mask[i] ^ 0xff) }
    Ip.new(broadcast)
  end
end

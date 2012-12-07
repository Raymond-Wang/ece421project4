require "socket"
require "pry"

module Util
  module_function
  # Yield a random port number.
  # Retries `limit' times or until success.
  def port_retry(limit=10)
    begin
      port = rand(100) + 50500
      yield port
    rescue Errno::EADDRINUSE
      port = nil
      limit = limit - 1
      retry unless limit <= 0
    end
    port
  end

  def get_ip
    socks = Socket::ip_address_list
    socks.detect{|intf| intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast? and !intf.ipv4_private?}.ip_address
  end

  def get_ip
    socks = Socket::ip_address_list
    socks.detect{|intf| intf.ipv4_private?}.ip_address
  end

  def debug(*args)
    callers = caller
    @flags ||= []
    if @flags.any? { |f| callers.grep(f).length > 0 }
      puts callers[0]
      puts *args
      puts "\n"
    end
  end

  def debug_conf(*args)
    @flags = args
  end
end

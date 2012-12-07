require "./util"
require "xmlrpc/server"
require "pry"

class MyClass
  def test(a)
    "Did a Test"
  end
end

ip = Util.get_ip
server = XMLRPC::Server.new 50550, ip
server.add_handler "game", MyClass.new
Thread.new do
  server.serve
end
binding.pry

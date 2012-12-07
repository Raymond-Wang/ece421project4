require "./server"
require "./util"
ip = Util.get_ip
server = nil
Util.port_retry do |port|
  server = GameServer.new port, ip
end
server.serve

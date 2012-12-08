require "./server"
require "./util"
ip = Util.get_ip
server = nil
server = GameServer.new 50500, ip
Util.biglog ip
server.serve

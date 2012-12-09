require "./server"
require "./util"
ip = Util.get_ip
server = nil
if ARGV.length == 2
  server = GameServer.new ARGV[1], ARGV[2]
else
  puts "Using defaults: runserver 50500 localip"
  server = GameServer.new 50500, ip
end
Util.biglog ip
server.serve

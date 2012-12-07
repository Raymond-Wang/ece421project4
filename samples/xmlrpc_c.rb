require "xmlrpc/client"
require "./util"

ip = Util.get_ip
puts ip
server = XMLRPC::Client.new ip, "/", 50550

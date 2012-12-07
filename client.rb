require "xmlrpc/client"
require "socket"

require "./util"
require "./dummygame"


# Receives updates from the game server.
class ClientProxy
  def initialize(client)
    @client = client
  end

  def notify_place_tile(col)
    Util.debug @client.game.inspect
    @client.game.place_tile col
    true
  end

  def notify_player(player)
    Util.debug @client.game.inspect
    @client.game.add_player player
    true
  end
  
  def notify_start(player)
    @client.game.start player
    true
  end
end

class Client
  TIMEOUT = 3600

  attr_accessor :game

  def initialize(game,player,host,port)
    @game, @host, @port, @player = game, host, port, player
    @myhost = Util.get_ip

    # So now client can send requests to the sever.
    # How does the server communicate with client?
    @out = XMLRPC::Client.new @host, "/", @port

    @proxy = ClientProxy.new self
    # Rertry until success
    @service_port = Util.port_retry do |port|
      @in = XMLRPC::Server.new port, @myhost
      @in.add_handler "game", @proxy
    end

    if @service_port.nil? or @in.nil?
      raise "Failed client service server."
    else
      serve
    end
    greet
  end

  def serve
    @thread = Thread.new do
      @in.serve
    end
  end
  private :serve

  def greet
    call "greet", @myhost, @service_port
  end

  def wait(time)
    call "wait", time
  end

  def place_tile(col)
    @game.place_tile col
    call "place_tile", col
  end

  def call(m,*args)
    @out.call "game.#{m}", @player, *args
  end

end

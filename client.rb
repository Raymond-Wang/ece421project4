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
  # 3 seconds should be plenty locally
  TIMEOUT = 3

  attr_accessor :game

  def initialize(player,host,port)
    @host, @port, @player = host, port, player
    @myhost = Util.get_ip

    # So now client can send requests to the sever.
    # How does the server communicate with client?
    @out = XMLRPC::Client.new @host, "/", @port
    @out.timeout=Client::TIMEOUT

    @proxy = ClientProxy.new self
    # Rertry until success
    @myport = Util.port_retry do |port|
      @in = XMLRPC::Server.new port, @myhost
      Util.biglog "Client server: #{@myhost}:#{port}"
      @in.add_handler "game", @proxy
    end

    if @myport.nil? or @in.nil?
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
    rpc "greet", @myhost, @myport
  end

  def create(game_type)
    precondition do
      # I don't want to repeat myself with the assertions 
      # inside of the game model. But lets at least confirm this much...
      raise unless game_type > 0
    end

    id = rpc "create", game_type 
    @game = Game.get(id)

    postcondition do
      raise if not(@game.id)
    end
  end

  def join(id)
    precondition do
      raise unless id > 0
    end

    id = rpc "join", id  
    @game = Game.get(id)

    postcondition do
      raise if not(@game.id)
    end
  end

  def wait(time)
    rpc "wait", time
  end

  def place_tile(col)
    @game.place_tile col
    rpc "place_tile", col
  end

  def rpc(m,*args)
    @out.call "game.#{m}", @player.to_s, *args
  end

end

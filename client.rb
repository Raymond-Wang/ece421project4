require "xmlrpc/client"
require "xmlrpc/server"
require "socket"
require "./util"
require "./dummygame"


# Receives updates from the game server.
class ClientProxy
  def initialize(client)
    @client = client
  end

  def notify_place_tile(col)
    Util.biglog "Got the Start Message"
    true
  end

  def notify_player(player)
    Util.biglog "Got the Start Message"
    true
  end
  
  def notify_start(id)
    @client.start id
    true
  end
end

class Client 

  TIMEOUT = 10 

  attr_accessor :game

  def initialize(player,host,port,timeout=Client::TIMEOUT)
    @host, @port, @player = host, port, player
    @myhost = Util.get_ip
    @sem = Mutex.new

    # So now client can send requests to the sever.
    # How does the server communicate with client?
    @out = XMLRPC::Client.new @host, "/", @port
    @out.timeout=Client::TIMEOUT

    @proxy = ClientProxy.new(self)

    # Rertry until success
    @sem.synchronize do
      @myport = Util.port_retry do |port|
        @in = XMLRPC::Server.new port, @myhost
        @in.add_handler "gameclient", @proxy
        Util.biglog "Client server: #{@myhost}:#{port}"
      end
    end
  end

  def serve
    Thread.new do
      @in.serve
    end
    true
  end

  def start
    @game.sync
    # Need to wait for a game join.
    @game.start player
  end

  def greet
    Util.biglog "Greetings from #{@myhost}:#{@myport}"
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
      raise unless id
    end
  end

  # Id is the game.
  def join(id)
    precondition do
      raise unless id > 0
    end

    id = rpc "join", id  

    @game = Game.get(id)

    postcondition do
      raise unless id
    end
  end

  def start(id)
    @game = id
  end

  def wait(time)
    rpc "wait", time
  end

  def place_tile(col)
    @game.place_tile col
    rpc "place_tile", col
  end

  def rpc(m,*args)
    @out.call "game.#{m}", @player.name, *args
  end

end

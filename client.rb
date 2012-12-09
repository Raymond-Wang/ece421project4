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

  def sync
    Util.biglog "Got the Sync Message for #{@client.player.name}"
    @client.sync 
    true
  end
  
  def notify_start(player)
    Util.biglog "Got the Start Message for #{@client.player.name}"
    begin
      @client.start player
    rescue Exception => e
      binding.pry
    end
    true
  end
end

class Client 

  TIMEOUT = 1000 

  attr_reader :game, :player

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

  def game=(game)
    Util.biglog "Setting game. If overwriting an existing one, we may have bugs."
    @game = game
  end

  def serve
    Thread.new do
      @in.serve
    end
    true
  end

  # Receives a game start event form the server.
  def start(player)
    precondition do
      raise "Player not provided." if player.nil?
    end
    @game.sync
    @game.start player
  end

  # Receives a game sync event from the server.
  def sync
    @game.sync
  end


  ## REMOTE COMMANDS ##

  def greet
    precondition do 
      raise if @myhost.nil? or @myport.nil?
    end
    rpc "greet", @myhost, @myport
  end

  # Joins a game with the given id.
  def join(id)
    precondition do
      raise unless id > 0
    end

    id = rpc "join", id  
    @game.sync
    
    postcondition do
      raise unless id
    end
  end

  def wait(time)
    rpc "wait", time
  end

  def place_tile(col)
    precondition do 
      raise "Column should be a number." unless col.kind_of? Numeric
    end
    @game.place_tile col
    rpc "place_tile", col, @game.id
  end

  def rpc(m,*args)
    begin
      @out.call "game.#{m}", @player.name, *args
    rescue XMLRPC::FaultException => e
      binding.pry
    end
  end

end

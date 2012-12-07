require "xmlrpc/server"
require "thread"
require "./util"
require "./dummygame"

class GameProxy
  def initialize(gameserver)
    @gameserver = gameserver
  end

  def connect
    return @gameserver.event_port
  end

  def place_tile(player, col)
    @gameserver.place_tile player, col
    col
  end

  def echo(player, val)
    val
  end

  def wait(player, time)
    sleep(time)
    time
  end

  def greet(player,hostname,service_port)
    @gameserver.greet player, hostname, service_port
  end
end

# We need to identify which client the request came from which requires us to 
# enforce a standard protocol where each client request should identity it's
# client.
# 
# We use to communicate game updates with each player who should be running
# their own xmlrpc server.
class ClientChannel
  attr_accessor :player, :host, :port, :out
  def initialize(player, host, port)
    @player, @host, @port = player, host, port
    @out = XMLRPC::Client.new host, "/", port
  end

  def method_missing(m, *args, &block)
    @out.call_async "game.#{m}", *args
  end
end

class GameConnection
  def initialize
    @channels
  end
end

class GameServer
  attr_accessor :game

  def initialize(port, ip=Util.get_ip)
    @port = port
    @game = game
    @server = XMLRPC::Server.new @port, ip

    # Because we can't pend for events on the RPC
    # server without resorting to bad long polling hacks
    # which are complicated by the fact that we migh lose
    # syncrhonization of our clients.
    @proxy = GameProxy.new self 
    @server.add_handler "game", @proxy 

    server = @server
    @thread = Thread.new do
      server.serve
    end

    # Store our connected clients here.
    @channels = []
    
    @game = DummyGame.new
  end

  # Acknowledges a new player with a corresponding service running
  # on their port.
  def greet(player,host,port)
    begin
      @channels << ClientChannel.new(player, host, port)
      @game.add_player player
      notify_player player, player
    rescue
      # TODO Check for exceptions.
      return false
    end
    return true
  end

  def start(player)
    @game.start player
    notify_start player
  end

  def place_tile(player, col)
    @game.place_tile col
    notify_place_tile col, player
  end

  def notify_start(player)
    with_channels do |channel|
      channel.notify_start player
    end
  end

  def notify_turn(turn,except=nil)
    with_channels except do |channel|
      channel.notify_turn turn
    end
  end

  def notify_place_tile(col,except=nil)
    with_channels except do |channel|
      #TODO check return values from client.
      channel.notify_place_tile col
    end
  end

  def notify_player(player,except=nil)
    Util.debug "calling notify_player"
    with_channels except do |channel|
      channel.notify_player player
    end
  end

  def with_channels(except=nil)
    @channels.reject { |c| c.player == except }.each do |channel|
      yield channel
    end
  end

end

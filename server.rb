require "xmlrpc/server"
require "xmlrpc/client"
require "thread"
require "./util"
require "./dummygame"
require "./models"

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

  def greet(player,host,service_port)
    @gameserver.greet player, host, service_port
  end

  def join(player,id)
    @gameserver.join player, id 
  end

  def create(player,game_type)
    @gameserver.create player, id, game_type
  end
end

# We need to identify which client the request came from which requires us to 
# enforce a standard protocol where each client request should identity it's
# client.
# 
# We use to communicate game updates with each player who should be running
# their own xmlrpc server.
class ClientChannel
  attr_accessor :player, :host, :port, :out, :ready
  def initialize(player, host, port)
    @player, @host, @port = player, host, port

    # Some mechanisms for robustness.
    @sem = Mutex.new
    @receipt = 1
    @history = []
    @out = XMLRPC::Client.new host, "/", port
    # Doesn't quite fit. Client is read to start the game.
    @ready = false
  end

  def method_missing(m, *args, &block)
    Thread.new do
      @out.call "gameclient.#{m}", *args
    end
  end
end

class GameServer
  attr_accessor :game

  # Exposed so we can join the thread.
  attr_reader :thread

  def initialize(port, host=Util.get_ip)
    @host = host
    @port = port
    @game = game

    @server = XMLRPC::Server.new @port, @host

    # Because we can't pend for events on the RPC
    # server without resorting to bad long polling hacks
    # which are complicated by the fact that we migh lose
    # syncrhonization of our clients.
    @proxy = GameProxy.new self 
    @server.add_handler "game", @proxy 

    # Store our connected clients here.
    @channels = Hash.new 

    # Use one Mutex per server for a few critical sections.
    # It's not the most effecient means of doing it - we could likely
    # have a more granular configuration.
    @sem = Mutex.new
  end

  def serve
    Util.biglog "Server running on #{@host}:#{@ip}"
    @server.serve
    Util.biglog "Server Done"
  end

  # Acknowledges a new player with a corresponding service running
  # on their port.
  def greet(player,host,port)
    player = Player.first_or_create(name: player)
    # Don't allow multiple connections from the same name.
    @sem.synchronize do
      # TODO Already exists.
      if @channels.has_key? player.name then return false end
      begin
        @channels[player.name] = ClientChannel.new(player.name, host, port)
      rescue Exception => e
        binding.pry
        # TODO Check for exceptions.
        return false
      end
    end
    return true
  end

  def create(player, game_type)
    game = Game.create game: game_type
    game.players << Player.first_or_create(name: player)
    game.save 
    @channels[player].ready = true
    return game.id
  end

  def join(player,id)
    Util.biglog "Player: #{player} is joining..."
    game = Game.get(id)
    player = Player.first_or_create name: player

    # Rejoining our own game?
    if not game.players.include? player
      # Ensure we don't let more than 2 players squeeze in.
      @sem.synchronize do
        if game.players and game.players.length >= 2
          Util.debug "Too many players in the game."
          return false
        end
        game.players <<  player
      end
    end
    @channels[player.name].ready = true
    if ready? game
      start (game)
    end
    return game.id
  end

  def start(game)
    precondition do
      game.state == Game::WAITING
      game.players.length == 2
    end
    game.reset
    game.save!
    notify_start game
    postcondition do
      game.state == Game::ONGOING
    end 
    true
  end

  def ready?(game)
    game.players.length == 2 and game.players.all? do |player|
      @channels[player.name].ready
    end
  end

  # These handle communications between clients.
  def notify_start(game)
    Util.biglog "Game is Starting"
    # This is bizarre. The async calls inside of clientchannel shouldn't block.
    # But they do. Nightmareish deadlock issue there.
    for player in game.players do
      channel = @channels[player.name]
      channel.out.call "gameclient.notify_start", game.players.first.name
    end
    true
  end


end

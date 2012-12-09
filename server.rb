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

  ## DIAGNOSTIC COMMANDS ##
  def echo(player, val)
    val
  end

  def wait(player, time)
    sleep(time)
    time
  end

  # Uses pry extension/gem to enter an interactive
  # console when an exception happens so that we can inspect things.
  # Uses 'exit' to continue.
  def debug_block 
    begin
      yield
    rescue Exception => e
      binding.pry
    end
  end

  ## ACTUAL COMMANDS ##
  def place_tile(player, col, id)
    debug_block  do
      @gameserver.place_tile player, col, id
    end
    col
  end

  def greet(player,host,service_port)
    debug_block do
        @gameserver.greet player, host, service_port
    end
  end

  def join(player,id)
    debug_block do
      @gameserver.join player, id 
    end
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
    @sem2 = Mutex.new
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
    Util.biglog "Hello #{player}"
    @sem.synchronize do
      # TODO Already exists.
      if @channels.has_key? player.name then return false end
      begin
        @channels[player.name] = ClientChannel.new(player.name, host, port)
      rescue Exception => e
        binding.pry
        return false
      end
    end
    return true
  end

  # Joins a given player to a game. If this cause the game to be ready, then
  # we also start the game.
  def join(player,id)
    Util.biglog "Player: #{player} is joining game id: #{id}"
    @sem.synchronize do
      game = Game.get(id)
      player = Player.first_or_create name: player

      # Rejoining our own game?
      if not game.players.include? player
      # Ensure we don't let more than 2 players squeeze in.
        if game.players and game.players.length >= 2
          Util.debug "Too many players in the game."
          return false
        end
        game.players << player
        game.save
      end

      if @channels[player.name].nil?
        # Well.. the server lots it's pipe to client.
        raise "No channel to connecting client."
      else
        @channels[player.name].ready = true
        if ready? game
          start (game)
        end
      end
    end
    id
  end

  # Places a tile in the game.
  def place_tile(player,col,id)
    game = Game.get(id)
    @sem.synchronize do
      async_game_channels game do |channel|
        channel.out.call "gameclient.sync"  
      end
    end
    true
  end

  # Gets the game started and notifies clients.
  def start(game)
    precondition do
      game.state == Game::WAITING
      game.players.length == 2
    end
    @sem2.synchronize do
      game.state = Game::ONGOING
      game.currentPlayer = game.players.first.name
    end
    notify_start game
    postcondition do
      game.state == Game::ONGOING
    end 
    true
  end
  # Relies on synchronization from game.
  private :start

  # Are the clients ready? Is the game ready?
  def ready?(game)
    game.players.length == 2 and game.players.all? do |player|
      @channels[player.name].ready
    end
  end

  # Iterates over the servers channels to client for a given game.
  def game_channels(game)
    for player in game.players do
      channel = @channels[player.name]
      if not channel.nil?
        yield channel
      else
        Util.biglog "Player's channel is missing."
      end 
    end
  end

  # Wraps the game channels call in a thread to make it nonblocking.
  def async_game_channels(game)
    game_channels game do |channel|
      Thread.new do
        yield channel
      end
    end
  end

  # These handle communications between clients.
  def notify_start(game)
    Util.biglog "Game is Starting"
    async_game_channels game do |channel| 
      Util.biglog "Notifying..."
      channel.out.call "gameclient.notify_start", game.players.first.name
    end
    true
  end


end

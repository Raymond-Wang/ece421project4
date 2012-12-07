require "observer"
require 'data_mapper'
require "pry"

require "./contracts"
require "./init"
require "./error"
require "./strategy"

class Model
  include Observable
end

class Game < Model
  # Update types for observers
  U_BOARD = 0
  U_TURN = 1
  U_PLAYER = 2
  U_RESET = 3
  U_DIFFICULTY = 4
  U_GAME = 5
  U_state = 6

  # Ending states.
  WAITING = 3
  WIN = 2
  DRAW = 1
  ONGOING = 0
  STATES = [WIN,DRAW,ONGOING,WAITING]

  # Game types.
  GAME_C4 = "Connect 4" 
  GAME_OTTO = "Otto" 
  GAMES = [GAME_OTTO,GAME_C4]

  # Difficulty
  MIN_DIFFICULTY = 0
  MAX_DIFFICULTY = 2

  # Board dimensions.
  HEIGHT = 6
  WIDTH = 7

  MIN_PLAYERS = 2

  include DataMapper::Resource

  attr_accessor :client

  property :id, Serial
  property :board, Object, :default => lambda { |r,p| Game.blank_board }
  property :currentPlayer, String
  property :difficulty, Integer
  property :turn, Integer
  property :state, Integer, :default => WAITING
  property :gamename, String
  property :game, String
  has n, :players, :through => Resource
  
  # Useful for testing.
  def self.blank_board
    board = Array.new
    (0...HEIGHT).each do |r|
      board[r] = Array.new
      (0...WIDTH).each do |c|
        board[r][c] = nil
      end
    end
  end

  # Start the game.
  def start(currentPlayer)
    sync
    @currentPlayer = currentPlayer
    @state = ONGOING
    init_strategy
    computer_actions
  end

  def ready?
    @state == WAITING || @state == ONGOING and @players.length == 2
  end

  def difficulty=(dif)
    precondition do
      raise "Bad difficulty." unless dif.respond_to?(:between?) and dif.between?(MIN_DIFFICULTY,MAX_DIFFICULTY)
    end
    super
    changed(true)
    notify_observers U_DIFFICULTY, dif
    if not @difficulty == dif
      raise PostconditionError, "Difficulty not set correctly."
    end
    @difficulty
  end

  # The game has been finished.
  def state=(state)
    if not STATES.include? state
      raise PreconditionError, "Invalid game victory state."
    end
    super
    changed(true)
    notify_observers U_state, state, @currentPlayer
    if not @state == state
      raise PostconditionError, "State not set correctly."
    end
    @state
  end

  def game=(game)
    precondition do
      raise "Strategy was not valid." unless GAMES.include? game
    end
    super
    changed(true)
    notify_observers U_GAME, game
    postcondition do
      raise "Game type not set" unless @game == game
    end
    @game
  end

  def turn=(turn)
    if not turn.kind_of? Numeric
      raise PreconditionError, "Turn is not a number."
    end
    super
    changed(true)
    notify_observers U_TURN, turn
    postcondition do
      raise "Turn not set correctly." unless @turn == turn
    end
  end
  
  def players=(players)
    Util.biglog "Assigning players"
    precondition do
      if not(players.respond_to? :each)
        raise PreconditionError, 'Players should be an enumerable.'
      else
        players.each { |p| 
          if not p.kind_of? Player 
            raise PreconditionError, 'Players enumerable should only contain player objects.'
          end
        }
      end
    end
    super
    postcondition do
      if not @players.length == players.length
        raise PostconditionError, "Players not set correctly."
      end
    end
  end

  # Somewhat of a factory method for the strategy but 
  # we don't yet require a factory abstraction
  def init_strategy
    if @game == GAME_C4 
      @strategy = C4Strategy.new self
    elsif @game == GAME_OTTO
      @strategy = OttoStrategy.new self
    end
    postcondition do
      raise "Strategy not initialized." if @strategy.nil?
    end
  end

  # Strategy dependent methods are delegated.
  def win?
    @strategy.win?
  end

  def movesRemaining?
    @turn < WIDTH*HEIGHT
  end

  def computer_actions
    @players.reject { |p| p.type != Player::TYPE_AI } .each do
      # Delay ai's move so it appears to think
      Thread.new do
        sleep 0.3
        move = @strategy.move
        place_tile(move)
      end
    end
  end

  def move
    @strategy.move
  end

  def canMove?
    @players[@currentPlayer].type != Player::TYPE_AI and @state == ONGOING
  end

  # col is the 0 indexed column
  def check_col(col)
    (0...HEIGHT).each { |r|
      if @board[r][col] == nil
        return true
      end
    }
    false
  end

  # Col is 0 indexed
  def place_tile(col)
    precondition do
      raise "Game is done." unless @state == Game::ONGOING
      raise "Not enough player." unless @players.length >= MIN_PLAYERS
    end

    body = lambda do
      if not col.between?(0,WIDTH-1)
        raise PreconditionError, "Column outside of range."
      end

      return false unless check_col(col)

      r,c = next_tile(col)
      @board[r][c] = current_piece
      changed(true)

      # Provide 1 indexed values externally.
      notify_observers U_BOARD, r, c, @board[r][c]

      # Sets and checks!
      check_status

      if @state == Game::ONGOING
        next_turn
      end

      return true
    end

    initial_turn = @turn
    result = body.call

    postcondition do
      # Rubyism
      if not !!result == result
        raise PostconditionError, "Result should be boolean."
      else
        if @state == Game::ONGOING and result and @turn == initial_turn
          raise PostconditionError, "Turn should have advanced if the tile was placed."
        end
      end
    end
    result
  end

  def status
    @strategy.status
  end

  # Check and assign completion state by checking with the strategy.
  def check_status
    precondition do
      raise "Strategy is incomplete." unless @strategy.respond_to? :status
    end
    status = @strategy.status
    state = Game::ONGOING
    case status
    when Strategy::P1_WIN
      state = Game::WIN
    when Strategy::P2_WIN
      state = Game::WIN
    when Strategy::DRAW
      state = Game::DRAW
    else
      if not movesRemaining?
        state = Game::DRAW
      else
        state = Game::ONGOING
      end
    end
    if state != Game::ONGOING
      self.state = state
    end
    postcondition do
      if state == Game::ONGOING and not movesRemaining?
        raise "Game is no longer ongoing and should be completed."
      end
    end
    @state
  end

  # Re-trigger notifications on all object properties.
  def sync
    reload
    # Accesses all variables as a creative way of sending signals.
    self.turn
    self.game
    self.players
    self.difficulty
    self.currentPlayer
  end

  # Reset the game to the starting turn. Give control to the first player.
  def reset
    self.turn = 1
    self.currentPlayer = 0
    self.state = Game::ONGOING
    (0...HEIGHT).each do |r|
      (0...WIDTH).each do |c|
        @board[r][c] = nil
        changed(true)
        notify_observers U_BOARD, r, c, @board[r][c]
      end
    end
    postcondition do
      raise "Turn should be set to one after reset." unless @turn == 1
    end
    # Let the computer move if necessary.
    computer_actions
  end

  def get_tile(r,c) 
    if not r.between?(1,HEIGHT)
      raise PreconditionError, "Row outside of range."
    end

    if not c.between?(1,WIDTH)
      raise PreconditionError, "Col outside of range."
    end
  end

  # Advance to the next turn and cycle through per-turn actions.
  def next_turn
    precondition do
      raise "Game is not ongoing." unless @state == Game::ONGOING
      raise "Not enough players" unless @players.length > MIN_PLAYERS
    end
    self.turn = @turn + 1
    self.currentPlayer  = @players.find { |p| p != @currentPlayer }
    # Move if necessary.
    computer_actions
  end

  def turn=(val)
    super
    changed(true)
    notify_observers U_TURN, @turn
  end

  def currentPlayer=(player)
    precondition do
      raise unless @players or @players.include? player
    end
    @currentPlayer = player
    changed(true)
    notify_observers U_PLAYER, @currentPlayer
  end

  def current_piece
    @turn % 2
  end

  # col should be 0 indexed
  # TODO private
  def next_tile(col)
    result = nil
    (HEIGHT-1).downto(0) { |i|
      if @board[i][col] == nil
        result = [i,col]
        break
      end
    }
    if result != nil 
      r, c = result
      if not r.between?(0,HEIGHT-1) then raise PostconditionError, "Row outside of range." end
      if not c.between?(0,WIDTH-1) then raise PostconditionError, "Col outside of range." end
    end
    result
  end

  # Returns 0 indexed row and column for element number i (if we start at
  # the top left and increase by one towards the bottom right).
  def indices(i)
    [(i/WIDTH),(i-1) % (WIDTH)]
  end

  def to_s
    (0...HEIGHT).each { |r|
      (0...WIDTH).each { |c|
        puts "#{@board[r][c].nil? ? '-' : @board[r][c]}"
      }
      puts "\n"
    }
  end
end

# In contrast to the game model, this one is simple enough to stash.
class Player < Model
  include DataMapper::Resource

  TYPE_AI = 'AI'
  TYPE_HUMAN = 'HUMAN'
  TYPES = [TYPE_AI,TYPE_HUMAN]

  property :type, String
  property :name, String, :key => true
  property :elo, Integer
  has n, :games, :through => Resource

  def initialize(name,type=TYPE_HUMAN)
    precondition do
      if not name.respond_to? :to_s
        raise "Players name cannot be represented as a string."
      end
      if not TYPES.include? type
        raise  "Invalid player type."
      end
    end
    super name: name, type: type
  end

  def desc
    if @type == TYPE_AI
      return "Computer Opponent"
    else
      return "Human"
    end
  end
end

class Move < Model
  attr_accessor :x, :y
  def initialize(x,y)
    @x, @y = x, y
  end
end

# Because of the complexity of the game model.
# We don't want to to incorporate model functionality directly.
# Instead, we'll use this class to stash game state and reload it.
# This is admittedly, a design smell.
class GameState
end

DataMapper.finalize
DataMapper.auto_migrate!

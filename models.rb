require "observer"
require 'data_mapper'
require "pry"

require "./contracts"
require "./init"
require "./error"
require "./strategy"

module SimpleObserver
  def add_observer(observer)
    @observers ||= []
    @observers << observer
  end

  def notify_obsevers(cmd,*args)
    for obs in @observers
      @observers.send cmd, *args
    end
  end
end

class Model
  include Observable
  def get_observers
    @observer_peers
  end
end

class Game < Model
  include DataMapper::Resource

  # Update types for observers
  U_BOARD = 0
  U_TURN = 1
  U_PLAYER = 2
  U_RESET = 3
  U_DIFFICULTY = 4
  U_GAME = 5
  U_COMPLETED = 6

  # Ending states.
  WAITING = 3
  WIN = 2
  DRAW = 1
  ONGOING = 0
  STATES = [WIN,DRAW,ONGOING,WAITING]

  # Game types.
  GAME_C4 = 0
  GAME_OTTO = 1
  GAMES = [GAME_OTTO,GAME_C4]

  # Difficulty
  MIN_DIFFICULTY = 0
  MAX_DIFFICULTY = 2

  # Board dimensions.
  HEIGHT = 6
  WIDTH = 7

  REQUIRED_PLAYERS = 2


  attr_accessor :client

  property :id, Serial
  property :board, Object, :default => lambda { |r,p| Game.blank_board }
  property :currentPlayer, String 
  property :difficulty, Integer, :default => 0
  property :turn, Integer, :default => 1
  property :state, Integer, :default => WAITING
  property :gamename, String, :default => "Brand Spanking New"
  property :game, Integer, :default => GAME_C4
  has n, :players, :through => Resource

  @@sem = Mutex.new
  
  # Useful for testing.
  def self.blank_board
    board = Array.new
    (0...HEIGHT).each do |r|
      board[r] = Array.new
      (0...WIDTH).each do |c|
        board[r][c] = nil
      end
    end
    board
  end

  # Start the game.
  def start(currentPlayer)
    reload
    self.currentPlayer = currentPlayer
    self.state = ONGOING
    self.players = self.players
    self.turn = 1
    save
    init_strategy
    computer_actions
  end

  def ready?
    self.state == WAITING || self.state == ONGOING and self.players.length == 2
  end

  def difficulty=(dif)
    precondition do
      raise "Bad difficulty." unless dif.respond_to?(:between?) and dif.between?(MIN_DIFFICULTY,MAX_DIFFICULTY)
    end
    super
    changed(true)
    notify_observers U_DIFFICULTY, dif
    if not self.difficulty == dif
      raise PostconditionError, "Difficulty not set correctly."
    end
    self.difficulty
  end

  # The game has been finished.
  def state=(state)
    if not STATES.include? state
      raise PreconditionError, "Invalid game victory state."
    end
    super
    changed(true)
    notify_observers U_COMPLETED, state, self.currentPlayer
    if not self.state == state
      raise PostconditionError, "State not set correctly."
    end
    self.state
  end

  def game=(game)
    precondition do
      raise "Strategy was not valid." unless GAMES.include? game
    end
    super
    changed(true)
    notify_observers U_GAME, game
    postcondition do
      raise "Game type not set" unless self.game == game
    end
    self.game
  end

  def turn=(turn)
    if not turn.kind_of? Numeric
      raise PreconditionError, "Turn is not a number."
    end
    super
    changed(true)
    notify_observers U_TURN, turn
    postcondition do
      raise "Turn not set correctly." unless self.turn == turn
    end
  end

  def player=(player)
    notify_observers U_PLAYER self.currentPlayer
    super
  end

  # Somewhat of a factory method for the strategy but 
  # we don't yet require a factory abstraction
  def init_strategy
    if self.game == GAME_C4 
      @strategy = C4Strategy.new self
    elsif self.game == GAME_OTTO
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
    self.turn < WIDTH*HEIGHT
  end

  def computer_actions
    self.players.reject { |p| p.type != Player::TYPE_AI } .each do
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

  def game_label
    map = { GAME_C4 => "C4", GAME_OTTO =>"Otto"}
    map[self.game]
  end

  def state_label
    map =  { 1 => "Draw", 2 =>"Over", 3 =>"Waiting", 0 => "Ongoing" }
    map[self.state]
  end

  def can_move?
    self.players.find { |v,k| v.type != Player::TYPE_AI } and self.state == ONGOING
  end

  # col is the 0 indexed column
  def check_col(col)
    (0...HEIGHT).each { |r|
      if self.board[r][col] == nil
        return true
      end
    }
    false
  end

  # Col is 0 indexed
  def place_tile(col)
    precondition do
      raise "Game is done." unless (self.state == Game::ONGOING or self.state == Game::WAITING)
      raise "Not enough player." unless self.players.length == REQUIRED_PLAYERS
    end

    # Set state to ongoig if we've been waiting.
    self.state = Game::ONGOING

    body = lambda do
      if not col.between?(0,WIDTH-1)
        raise PreconditionError, "Column outside of range."
      end

      return false unless check_col(col)

      r,c = next_tile(col)

      @@sem.synchronize do
        # This is a hack to make datamapper objects save. It doesn't seem
        # to recognize minor changes to content to I trick it by 
        # doing this. Ugh.
        self.board[r][c] = current_piece
        board = self.board.dup
        self.board = 1
        save
        self.board = board
        save
      end

      changed(true)

      # Provide 1 indexed values externally.
      notify_observers U_BOARD, r, c, self.board[r][c]

      # Sets and checks!
      check_status

      if self.state == Game::ONGOING
        next_turn
      end
      return true
    end

    initial_turn = self.turn
    result = body.call

    postcondition do
      # Rubyism
      if not !!result == result
        raise "Result should be boolean."
      else
        if self.state == Game::ONGOING and result and self.turn == initial_turn
          raise "Turn should have advanced if the tile was placed."
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
      if @strategy.nil?
        init_strategy
      end
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
    self.state
  end

  # Re-trigger notifications on all object properties.
  def sync
    @@sem.synchronize do
      reload
      # Accesses all variables as a creative way of sending signals.
      self.turn = self.turn
      self.game = self.game
      self.state = self.state
      self.players = self.players
      self.difficulty = self.difficulty
      self.currentPlayer = self.currentPlayer
      self.board = self.board
      board_each do |r,c|
        changed(true)
        notify_observers U_BOARD, r, c, @board[r][c]
      end
    end
  end

  def board_each 
    (0...HEIGHT).each do |r|
      (0...WIDTH).each do |c|
        yield r,c
      end
    end
  end

  # Reset the game to the starting turn. Give control to the first player.
  def reset
    self.turn = 1
    self.state = ONGOING
    self.board # Triggers default value if necessary.
    self.players
    self.currentPlayer = self.players.first
    board_each do |r,c|
      self.board[r][c] = nil
      changed(true)
      notify_observers U_BOARD, r, c, self.board[r][c]
    end
    binding.pry
    postcondition do
      raise "Turn should be set to one after reset." unless self.turn == 1
    end
    # Let the computer move if necessary.
    computer_actions
  end

  # Advance to the next turn and cycle through per-turn actions.
  def next_turn
    precondition do
      raise "Game is not ongoing." unless self.state == Game::ONGOING
      raise "Not enough players" unless self.players.length == REQUIRED_PLAYERS
    end
    self.turn = self.turn + 1
    self.currentPlayer = self.players.find { |p| p.name != self.currentPlayer }.name
    save
    # Move if necessary.
    computer_actions
  end

  def turn=(val)
    super
    changed(true)
    notify_observers U_TURN, self.turn
  end

  def currentPlayer=(player)
    super
    changed(true)
    notify_observers U_PLAYER, self.currentPlayer 
  end

  def current_piece
    (self.turn % 2) + 1
  end

  # col should be 0 indexed
  def next_tile(col)
    result = nil
    (HEIGHT-1).downto(0) { |i|
      if self.board[i][col] == nil
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
        puts "#{self.board[r][c].nil? ? '-' : self.board[r][c]}"
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

  def desc
    if self.type == TYPE_AI
      return "Computer Opponent"
    else
      return "Human"
    end
  end
end

DataMapper.finalize
#DataMapper.auto_migrate!
DataMapper.auto_upgrade!

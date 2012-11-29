require "observer"
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
  U_COMPLETED = 6

  # Ending states.
  WIN = 1
  DRAW = 0
  ONGOING = nil
  STATES = [WIN,DRAW,ONGOING]

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

  MIN_PLAYERS = 2
  
  attr_accessor :game, :difficulty, :currentPlayer, :board
  attr_reader :players, :completed, :turn

  # Row 0 is at the top, Col 0 is on the left
  # In Connect 4, '1' is player piece, '2' is computer piece
  # In OTTO TOOT, '1' is O, '2' is T, and computer plays as TOOT

  def initialize(dif=3, players=[], game=GAME_C4)
    # Array of all players. Can be modified dynamically as players leave
    # and enter.
    self.players = players 
    self.currentPlayer = 0
    self.game = game 
    self.turn = 1
    self.difficulty = dif

    @board = Array.new(HEIGHT) { Array.new(WIDTH) } 
    # Initialize our strategy
    initStrategy
  end

  def difficulty=(dif)
    if not(dif.respond_to?(:between?) and dif.between?(MIN_DIFFICULTY,MAX_DIFFICULTY))
      raise PreconditionError, 'Invalid difficulty.'
    end
    @difficulty = dif
    changed(true)
    notify_observers U_DIFFICULTY, dif
    if not @difficulty == dif
      raise PostconditionError, "Difficulty not set correctly."
    end
  end

  # The game has been finished.
  def completed=(state)
    if not STATES.include? state
      raise PreconditionError, "Invalid game victory state."
    end
    if not state === ONGOING
      @completed = state
      changed(true)
      notify_observers U_COMPLETED, state, @players[@currentPlayer]
    end
    if not @completed == state
      raise PostconditionError, "State not set correctly."
    end
  end

  def game=(game)
    if not(GAMES.include? game)
      raise PreconditionError, "Strategy should be one of #{GAMES.inspect}"
    end
    @game=game
    initStrategy
    changed(true)
    notify_observers U_GAME, game
    if not @game == game
      raise PostconditionError, "Game type not set correctly."
    end
  end

  def turn=(turn)
    if not turn.kind_of? Numeric
      raise PreconditionError, "Turn is not a number."
    end
    @turn = turn
    changed(true)
    notify_observers U_TURN, turn
    if not @turn == turn
      raise PostconditionError, "Turn not set correctly."
    end
  end
  
  def players=(players)
    if not(players.respond_to? :each)
      raise PreconditionError, 'Players should be an enumerable.'
    else
      players.each { |p| 
        if not p.kind_of? Player 
          raise PreconditionError, 'Players enumerable should only contain player objects.'
        end
      }
    end
    @players = players
    if not @players.length == players.length
      raise PostconditionError, "Players not set correctly."
    end
  end

  # Somewhat of a factory method for the strategy but 
  # we don't yet require a factory abstraction
  def initStrategy
    if @game == GAME_C4 
      @strategy = C4Strategy.new self
    elsif @game == GAME_OTTO
      @strategy = OttoStrategy.new self
    end
    if @strategy.nil?
      raise PostconditionError, "Strategy not initialized."
    end
  end

  # Strategy dependent methods are delegated.
  def win?
    @strategy.win?
  end

  def movesRemaining?
    @turn < WIDTH*HEIGHT
  end

  def move
    @strategy.move
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
    if not @players.length >= MIN_PLAYERS
      raise PreconditionError, "Not enough players."
    end

    body = Proc.new do
      if not col.between?(0,WIDTH-1)
        raise PreconditionError, "Column outside of range."
      end

      return false unless check_col(col)

      r,c = next_tile(col)
      @board[r][c] = current_piece
      changed(true)
      # Provide 1 indexed values externally.
      notify_observers U_BOARD, r, c, @board[r][c]

      check_status

      if not self.completed
        next_turn
      end

      return true
    end

    initial_turn = @turn
    result = body.call
    # Rubyism
    if not !!result == result
      raise PostconditionError, "Result should be boolean."
    else
      if result and @turn == initial_turn
        raise PostconditionError, "Turn should have advanced if the tile was placed."
      end
    end
    result
  end

  # Check and assign completion state by checking with the strategy.
  def check_status
    raise PostconditionError, "Strategy is incomplete." unless @strategy.respond_to? :status
    status = @strategy.status
    completed = Game::ONGOING
    case status
    when Strategy::P1_WIN
      completed = Game::WIN
    when Strategy::P2_WIN
      completed = Game::WIN
    when Strategy::DRAW
      completed = Game::DRAW
    else
      if not movesRemaining?
        completed = Game::DRAW
      else
        completed = Game::ONGOING
      end
    end
    if completed != Game::ONGOING
      self.completed = completed
    end
    if completed == Game::ONGOING and not movesRemaining?
      raise PostconditionError, "Game is no longer ongoing and should be completed."
    end
    self.completed
  end

  # Re-trigger notifications on all object properties.
  def sync
    # Reassigns all variables as a ghetto way of sending out
    # signals to all observers.
    self.turn = @turn
    self.game = @game
    self.players = @players
    self.difficulty = @difficulty
    self.currentPlayer = @currentPlayer
    raise PostconditionError, "Notifiers should have been sent." unless not changed?
  end

  # Reset the game to the starting turn. Give control to the first player.
  def reset
    self.turn = 1
    self.currentPlayer = 0
    (0...HEIGHT).each do |r|
      (0...WIDTH).each do |c|
        @board[r][c] = nil
        changed(true)
        notify_observers U_BOARD, r, c, @board[r][c]
      end
    end
    if @turn != 1
      raise PostconditionError, "Turn should be set to one after reset."
    end
    if @currentPlayer != 0
      raise PostconditionError, "Player should be reset."
    end
  end

  def get_tile(r,c) 
    if not r.between?(1,HEIGHT)
      raise PreconditionError, "Row outside of range."
    end

    if not c.between?(1,WIDTH)
      raise PreconditionError, "Col outside of range."
    end
  end

  def next_turn
    if not @players.length >= MIN_PLAYERS
      raise PreconditionError, "Not enough players."
    end
    self.turn = @turn + 1
    self.currentPlayer = @currentPlayer = (@currentPlayer + 1) % @players.length
  end

  def turn=(val)
    @turn = val
    changed(true)
    notify_observers U_TURN, @turn
  end

  def currentPlayer=(player)
    if player > @players.length
      raise PreconditionError, "Invalid player number."
    end
    @currentPlayer = player
    changed(true)
    notify_observers U_PLAYER, @currentPlayer, @players[@currentPlayer]
  end

  def current_piece
    # Happens to work for now.
    @currentPlayer + 1
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
end

class Player < Model
  TYPE_AI = 'AI'
  TYPE_HUMAN = 'HUMAN'
  TYPES = [TYPE_AI,TYPE_HUMAN]

  attr_accessor :type, :name

  def initialize(name,type)
    if not name.respond_to? :to_s
      raise PreconditionError, "Players name cannot be represented as a string."
    end
    if not TYPES.include? type
      raise  PreconditionError, "Invalid player type."
    end
    @name, @type = name, type
  end

  def move
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


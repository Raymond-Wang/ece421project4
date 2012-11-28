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

  GAME_C4 = 0
  GAME_OTTO = 1
  GAMES = [GAME_OTTO,GAME_C4]
  MIN_DIFFICULTY = 1
  MAX_DIFFICULTY = 3
  HEIGHT = 6
  WIDTH = 7

  attr_accessor :game, :difficulty, :currentPlayer, :board
  attr_reader :players

  # Row 0 is at the top, Col 0 is on the left
  # In Connect 4, '1' is player piece, '2' is computer piece
  # In OTTO TOOT, '1' is O, '2' is T, and computer plays as TOOT

  def initialize(dif=1, players=[], game=GAME_C4)
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
  end

  def game=(game)
    if not(GAMES.include? game)
      raise PreconditionError, "Strategy should be one of #{GAMES.inspect}"
    end
    @game=game
    changed(true)
    notify_observers U_GAME, game
  end

  def turn=(turn)
    if not turn.kind_of? Numeric
      raise PreconditionError, "Turn is not a number."
    end
    @turn = turn
    changed(true)
    notify_observers U_TURN, turn
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
  end

  # Somewhat of a factory method for the strategy but 
  # we don't yet require a factory abstraction
  def initStrategy
    if @game == GAME_C4 
      @strategy = C4Strategy.new self
    elsif @game == GAME_OTTO
      @strategy = OttoStrategy.new self
    end
  end

  # Strategy dependent methods are delegated.
  def win?
    @strategy.win?
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
    if not col.between?(0,WIDTH-1)
      raise PreconditionError, "Column outside of range."
    end
    return false unless check_col(col)
    r,c = next_tile(col)
    @board[r][c] = current_piece
    changed(true)
    # Provide 1 indexed values externally.
    notify_observers U_BOARD, r, c, @board[r][c]
    next_turn
    true
  end

  def sync
    # Reassigns all variables as a ghetto way of sending out
    # signals to all observers.
    self.turn = @turn
    self.game = @game
    self.players = @players
    self.difficulty = @difficulty
    self.currentPlayer = @currentPlayer
  end

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

  attr_accessor :type, :name

  def initialize(name,type)
    @name, @type = name, type
  end

  def move
  end
end

class Move < Model
  attr_accessor :x, :y
  def initialize(x,y)
    @x, @y = x, y
  end
end


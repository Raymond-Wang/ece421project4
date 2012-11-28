#!/usr/bin/env ruby
require 'rubygems'
require 'gtk2'
require "observer"

class PreconditionError < StandardError; end
class PostconditionError < StandardError; end
class InvariantError < StandardError; end

class Model
  include Observable
end

class Game < Model
  # Update types for observers
  U_BOARD = 0

  GAME_C4 = 0
  GAME_OTTO = 1
  GAMES = [GAME_OTTO,GAME_C4]
  MIN_DIFFICULTY = 1
  MAX_DIFFICULTY = 3
  HEIGHT = 6
  WIDTH = 7

  attr_accessor :game, :difficulty, :currentPlayer
  attr_reader :players

  # Row 0 is at the top, Col 0 is on the left
  # In Connect 4, '1' is player piece, '2' is computer piece
  # In OTTO TOOT, '1' is O, '2' is T, and computer plays as TOOT

  def initialize(dif=1, players=[], game=GAME_C4)
    if not(dif.respond_to?(:between?) and dif.between?(MIN_DIFFICULTY,MAX_DIFFICULTY))
      raise PreconditionError, 'Invalid difficulty.'
    end
    if not(GAMES.include? game)
      raise PreconditionError, "Strategy should be one of #{GAMES.inspect}"
    end

    # Array of all players. Can be modified dynamically as players leave
    # and enter.
    @players = players 

    # Index of the current player.
    @currentPlayer = 0
    @turn = 1
    @difficulty = dif
    @game = game 
    @board = Array.new(HEIGHT) { Array.new(WIDTH) } 

    # Initialize our strategy
    initStrategy
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
      if @difficulty == 1
        @strategy = C4Easy.new self
      elsif @difficulty == 2
        @strategy = C4Medium.new self
      elsif @difficulty == 3
        @strategy = C4Hard.new self
      end
    elsif @game == GAME_OTTO
      if @difficulty == 1
        @strategy = OttoEasy.new self
      elsif @difficulty == 2
        @strategy = OttoMedium.new self
      elsif @difficulty == 3
        @strategy = OttoHard.new self
      end
    end
  end

  # Strategy dependent methods are delegated.
  def win?
    @strategy.win?
  end

  def move
    @strategy.move
  end

  # Check if the row has space.
  def check_col(col)
    col.step(HEIGHT*WIDTH-1, WIDTH).any? { |i| 
      r,c = indices(i)
      @board[r][c] == nil
    }
  end

  # Col is 1 indexed.
  def place_tile(col)
    return false unless check_col(col)
    r,c = next_slot(col)
    changed(true)
    # Provide 1 indexed values externally.
    notify_observers U_BOARD, r+1, c+1
    next_turn
    true
  end

  def next_turn
    @turn = @turn + 1
    @currentPlayer = (@currentPlayer + 1) % @players.length
  end

  def current_piece()
    # Happens to work for now.
    @currentPlayer + 1
  end

  def next_slot(col)
    ((HEIGHT*WIDTH)-(col+1)).step(0,-WIDTH) { |i|
      r, c = indices(i)
      if @board[r][c] == nil
        return r,c
      end
    }
    nil
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

# NOTE Strategies can have their own instance variables to help manage things.
# For example a hierarchical tree or whatever it takes. It has access
# to the full game state via game.
# The strategy is responsible for two, somewhat distinct goals:
# 1. Check if the current game state is a victory.
#
# Ideas (might be overkill!!)
# http://en.wikipedia.org/wiki/Minimax#Minimax_algorithm_with_alternate_moves
class Strategy < Model
  def initialize(game)
    # We give the stategy access to the entire gamemodel which
    # includes the board and stats on players.
    # Strategy might be player quantity dependent for example
    @game = game
  end

  def horizontal(i,j,arr)
    for k in 0..(arr.length-1)
      if @board[i][j+k] != arr[k]
        return false
      end
    end
    return true
  end

  def vertical(i,j,arr)
    for k in 0..(arr.length-1)
      if @board[i+k][j] != arr[k]
        return false
      end
    end
    return true
  end

  def diagonaldown(i,j,arr)
    for k in 0..(arr.length-1)
      if @board[i+k][j+k] != arr[k]
        return false
      end
    end
    return true
  end

  def diagonalup(i,j,arr)
    for k in 0..(arr.length-1)
      if @board[i-k][j+k] != arr[k]
        return false
      end
    end
    return true
  end

  def find(arr)
    if (arr.length > 6)
      raise PreconditionError, 'Search array too long.'
    end
    if (arr.empty)
      raise PreconditionError, 'Search array is empty.'
    end
    for i in 0..5
      for j in 0..(7-arr.length)
        if horizontal(i,j,arr)
          return i,j,'horizontal'
        end
      end
    end
    for i in 0..(6-arr.length)
      for j in 0..6
        if vertical(i,j,arr)
          return i,j,'vertical'
        end
      end
    end
    for i in 0..(6-arr.length)
      for j in 0..(7-arr.length)
        if diagonaldown(i,j,arr)
          return i,j,'diagonaldown'
        end
      end
    end
    for i in (arr.length-1)..5
      for j in 0..(7-arr.length)
        if diagonalup(i,j,arr)
          return i,j,'diagonalup'
        end
      end
    end
    return -1,-1,'notfound'
  end

  def top(i)
    for j in 6..0
      if @board[i][j] == 0
        return j
      end
    end
    return -1
  end

  def hasAdjacent(row,col,piece)
    fromI = (row == 5) ? 0 : -1
    toI = (row == 0) ? 0 : 1
    fromJ = (col == 0) ? 0 : -1
    toJ = (col == 6) ? 0 : 1
    for i in fromI..toI
      for j in fromJ..toJ
        if @board[row+i][col+j] == piece
          return true
        end
      end
    end
    return false
  end

  def move
    raise NotImplementedError, 'Concrete, game specific strategies should implement move.'
  end

  # Evaluate position based on minimax.
  # Perhaps we want per-player evaluation tables generated by running the
  # evaluation function?
  def evaluate
  end

  def win?
    raise NotImplementedError, 'Concrete, game specific strategies should implement win?.'
  end
end

class OttoEasy < Strategy
  def move
    begin 
      col = rand(7)
      row = top(col)
    end until row > -1
    @board[row][col] = 1 + rand(1);
  end

  def win?
    p1,a,b = find([2,1,1,2])
    p2,c,d = find([1,2,2,1])
    return p1>0 || p2>0
  end

  def winner
    p1,a,b = find([1,2,2,1])
    if p1>0
      return 1
    end
    p2,c,d = find([2,1,1,2])
    if p2>0
      return 2
    end
    return 0
  end
end

class OttoMedium < Strategy
  def win?
    p1,a,b = find([2,1,1,2])
    p2,c,d = find([1,2,2,1])
    return p1>0 || p2>0
  end

  def winner
    p1,a,b = find([1,2,2,1])
    if p1>0
      return 1
    end
    p2,c,d = find([2,1,1,2])
    if p2>0
      return 2
    end
    return 0
  end

  def move
    for col in 0..6
      if (top(col) > -1)
        @board[top(col)][col] = 2
      end
      if winner == 2
        return
      elsif winner == 1
        @board[top(col)][col] = 1
      end
    end
    begin 
      col = rand(7)
      row = top(col)
    end until row > -1
    @board[row][col] = 1 + rand(1);
  end

end


class C4Easy < Strategy
  def move
    begin 
      col = rand(6)
      row = top(col)
    end until row > -1
    @board[row][col] = 2;
  end

  def win?
    p1,a,b = find([1,1,1,1])
    p2,c,d = find([2,2,2,2])
    return p1>0 || p2>0
  end

end

class C4Medium < Strategy
  def win?
    p1,a,b = find([1,1,1,1])
    p2,c,d = find([2,2,2,2])
    return p1>0 || p2>0
  end

  def move
    for col in 0..6
      if (top(col) > -1)
        @board[top(col)][col] = 2
      end
      if win?
        return
      else 
        @board[top(col)][col] = 1
        if win?
          @board[top(col)][col] = 2
          return
        end
      end
    end
    begin 
      col = rand(6)
      row = top(col)
    end until row > -1
    @board[row][col] = 2;
  end
end

class C4Hard < Strategy
  def win?
    p1,a,b = find([1,1,1,1])
    p2,c,d = find([2,2,2,2])
    return p1>0 || p2>0
  end

  def move
    for col in 0..6
      if (top(col) > -1)
        @board[top(col)][col] = 2
      end
      if win?
        return
      else 
        @board[top(col)][col] = 1
        if win?
          @board[top(col)][col] = 2
          return
        end
      end
    end
    from = rand(6)
    to = rand(6)
    for col in from..to
      if(top(col) > -1)
        if(hasAdjacent(top(col),col,2))
          @board[top(col)][col] = 2
        end
      end
    end
    begin 
      col = rand(6)
      row = top(col)
    end until row > -1
    @board[row][col] = 2;
  end
end

# The builder is our view in this case.
class Controller
  attr :glade

  def initialize
    if __FILE__ == $0
      Gtk.init
      @builder = Gtk::Builder::new
      @builder.add_from_file("c4.glade")
      @builder.connect_signals{ |handler| method(handler) }

      # Destroying the window will terminate the program
      window = @builder.get_object("window1")
      window.signal_connect( "destroy" ) { Gtk.main_quit }

      # The 'Quit' button will terminate the program
      menu = @builder.get_object("Quit")
      menu.signal_connect( "activate" ) { Gtk.main_quit }

      # The 'New' button will start a new game
      menu = @builder.get_object("New")
      menu.signal_connect( "activate" ) { setUpTheBoard }

      # The 'Settings' button will open a new window called settings
      settings = @builder.get_object("Settings")
      settings.signal_connect( "activate" ) { openSettings() }

      # The 'Settings' button will open a new window called settings
      about = @builder.get_object("About")
      about.signal_connect( "activate" ) { openAbout() }

      # The 'OK' button in Settings will save the settings and close the window
      settingsOK = @builder.get_object("SettingsOK")
      settingsOK.signal_connect( "clicked" ) { saveSettings() }

      # The 'Cancel' button in Settings will negate any changes to the settings and close the window
      settingsCancel = @builder.get_object("SettingsCancel")
      settingsCancel.signal_connect( "clicked" ) { hideSettings() }

      # Attach a signal to each button
      1.upto(Game::WIDTH) { |i| 
        @builder.get_object("button" + i.to_s).signal_connect("clicked") {button_clicked(i)};
      }

      @game = Game.new 1

      @game.players = [Player.new('jacob', Player::TYPE_AI), Player.new('raymond', Player::TYPE_AI)]

      # Register observer
      @game.add_observer self, :update

      setUpTheBoard

      window.show()
      Gtk.main()
    end
  end

  def update(what,*args)
    p "Updating"
    case what
    when Game::U_BOARD
      update_board *args
    end
  end

  def update_board(row,col)
    i = col + ((row-1)*Game::WIDTH) 
    p "Update board called"
    p "image#{i}"
    @builder.get_object("image#{i}").pixbuf = Gdk::Pixbuf.new 'red.png'
  end


  def openSettings
    dialog = @builder.get_object("dialog1")
    dialog.show()
    gameCombo = @builder.get_object("GameCombo")
    difficultyCombo = @builder.get_object("DifficultyCombo")
    gameCombo.active=@game.game
    difficultyCombo.active=@game.difficulty
  end

  def saveSettings
    gameCombo = @builder.get_object("GameCombo")
    difficultyCombo = @builder.get_object("DifficultyCombo")
    @game = gameCombo.active
    @difficulty = difficultyCombo.active
    hideSettings()
  end

  def hideSettings
    dialog = @builder.get_object("dialog1")
    dialog.hide()
  end

  def openAbout
    about = @builder.get_object("window2")
    about.show()
  end

  def setUpTheBoard

  end

  def button_clicked(col)
    @game.place_tile(col)
  end  

  def win?

  end


  def threes(a,b,c)

  end


  def gtk_main_quit
    Gtk.main_quit()
  end


end


hello = Controller.new

#!/usr/bin/env ruby
require 'rubygems'
require 'gtk2'
require "observer"

require "./error"
require "./strategy"

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

  attr_accessor :game, :difficulty, :currentPlayer, :board
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

  def reset
    @turn = 0
    @currentPlayer = 0
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
    @turn = @turn + 1
    @currentPlayer = (@currentPlayer + 1) % @players.length
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
    when Game::U_RESET
      reset_board
    end
  end

  def update_board(row,col,piece)
    i = col + ((row)*Game::WIDTH) + 1
    @builder.get_object("image#{i}").pixbuf = Gdk::Pixbuf.new(image_for_piece(piece))
  end

  def image_for_piece(piece)
    return 'frame.png' unless not piece.nil?
    case @game.game
    when Game::GAME_OTTO
      case piece
      when 1
        'o.png'
      when 2
        't.png'
      end
    when Game::GAME_C4
      case piece
      when 1
        'black.png'
      when 2
        'red.png'
      end
    end
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
    game = gameCombo.active
    dif = difficultyCombo.active
    if game != @game.game or dif != @game.difficulty
      @game.game = game
      @game.difficulty = dif
      @game.reset
    end
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
    @game.place_tile(col-1)
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

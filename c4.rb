#!/usr/bin/env ruby
require 'rubygems'
require 'gtk2'

class PreconditionError < Error end
class PostconditionError < Error end
class InvariantError < Error end

class Game
    GAME_C4 = "C4"
    GAME_OTTO = "OTTO"
    GAMES = [GAME_OTTO,GAME_C4]
    HEIGHT = 5
    WIDTH = 7
    
    def initialize(dif, players)
        if not(dif.responds_to? :between? and dif.between?(1,3))
            raise PreconditionError, 'Invalid difficulty.'
        end
        if not(players.responds_to? :each?))
            raise PreconditionError, 'Players should be an enumerable.'
        else
            players.each { |p| 
                if not player.kind_of? Player 
                    raise PreconditionError, 'Players enumerable should only contain player objects.'
                end
            }
        end
        if not([GAMES].include? strategy)
            raise PreconditionError, "Strategy should be one of #{[GAMES.inspect]}"
        end

        @players = []
        @difficulty = 0
        @game = GAME_C4 
        @board = Array.new(HEIGHT) { Array.new(WIDTH) } 

        # Initialize our strategy
        initStrategy
    end

    # Somewhat of a factory method for the strategy but 
    # we don't yet require a factory abstraction
    def initStrategy
        if @game == GAME_C4 
            @strategy = Otto.new @
        elsif @game == GAME_OTTO
            @strategy = Strategy.new @
        end
    end


    # Strategy dependent methods are delegated.
    def win?
        @strategy.win?
    end
    
    def nextMove
        @strategy.nextMove
    end
end

class Player
    TYPE_AI = "AI"
    TYPE_HUMAN = "HUMAN"
    def initialize(name,type)
        @name, @type = name, type
    end
end

class Move
    attr_accessor :x, :y
    def initialize(x,y)
        @x, @y = x, y
    end
end

class Strategy
    def initialize(gameModel)
        # We give the stategy access to the entire gamemodel which
        # includes the board and stats on players.
        # Strategy might be player quantity dependent for example
        @gameModel = gameModel
    end
    
    def nextMove
        raise NotImplementedError, 'Concrete, game specific strategies should implement nextMove.'
    end
    
    def win?
        raise NotImplementedError, 'Concrete, game specific strategies should implement win?.'
    end
end

class OttoStrategy < Stragegy
end

class Connect4Strategy < Strategy
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
      1.upto(Game::HEIGHT*GAME::WIDTH) { |i| 
         @builder.get_object("button" + i.to_s).signal_connect("clicked") {button_clicked(i)};
      }

      @game = Game.new

      setUpTheBoard

      window.show()
      Gtk.main()
    end
  end

  def openSettings
    dialog = @builder.get_object("dialog1")
    dialog.show()
    gameCombo = @builder.get_object("GameCombo")
    difficultyCombo = @builder.get_object("DifficultyCombo")
    gameCombo.active=@game
    difficultyCombo.active=@difficulty
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

  def button_clicked(tileNumber)
      puts tileNumber
  end  


  def win?

  end


  def threes(a,b,c)

  end


  def gtk_main_quit
    Gtk.main_quit()
  end


end


hello = C4Glade.new

#!/usr/bin/env ruby
require 'rubygems'
require 'gtk2'

require "./error"
require "./models"
#
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
      menu.signal_connect( "activate" ) { @game.reset }

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
      # Synchronize ui
      @game.sync

      window.show()
      Gtk.main()
    end
  end

  def update(what,*args)
    case what
    when Game::U_BOARD
      update_board *args
    when Game::U_RESET
      reset_board *args
    when Game::U_PLAYER
      update_player *args
    when Game::U_TURN
      update_turn *args
    when Game::U_GAME
      update_game *args
    end
  end

  def update_board(row,col,piece)
    i = col + ((row)*Game::WIDTH) + 1
    @builder.get_object("image#{i}").pixbuf = Gdk::Pixbuf.new(image_for_piece(piece))
  end

  def update_game(game)
    @game = game
    @builder.get_object("game_type").text = game
  end

  def update_turn(turn)
    @builder.get_object("turn").text = "Turn: #{turn}" 
  end

  def update_game(game)
    case game
    when Game::GAME_OTTO
      label = "Otto"
    when Game::GAME_C4
      label = "Connect 4"
    end
    @builder.get_object("game_type").text = label
  end

  def update_player(current,player)
    @game.players.each_with_index do |player,i|
      label = @builder.get_object("player#{i+1}")
      desc = @builder.get_object("player#{i+1}desc")
      if current != i 
        label.text = "#{player.name}"
        desc.text = "#{player.type}"
      else
        label.set_markup("<span weight=\"bold\" foreground=\"#0097ff\">*#{player.name}</span>")
        desc.text = "#{player.type}"
      end
    end
  end

  def image_for_piece(piece)
    return 'assets/img/frame.png' unless not piece.nil?
    case @game.game
    when Game::GAME_OTTO
      case piece
      when 1
        'assets/img/o.png'
      when 2
        'assets/img/t.png'
      end
    when Game::GAME_C4
      case piece
      when 1
        'assets/img/black.png'
      when 2
        'assets/img/red.png'
      end
    end
  end
  private 


  def openSettings
    dialog = @builder.get_object("dialog1")
    dialog.show()
    gameCombo = @builder.get_object("GameCombo")
    difficultyCombo = @builder.get_object("DifficultyCombo")
    gameCombo.active=@game.game
    difficultyCombo.active=@game.difficulty
  end
  private 

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
  private

  def hideSettings
    dialog = @builder.get_object("dialog1")
    dialog.hide()
  end
  private

  def openAbout
    about = @builder.get_object("window2")
    about.show()
  end
  private
  
  def button_clicked(col)
    @game.place_tile(col-1)
    @game.place_tile(@game.move)
  end  

  def gtk_main_quit
    Gtk.main_quit()
  end


end


hello = Controller.new

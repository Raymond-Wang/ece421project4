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
      window.signal_connect( "destroy" ) { quit }

      # The 'Quit' button will terminate the program
      menu = @builder.get_object("Quit")
      menu.signal_connect( "activate" ) { quit }

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

      victoryQuit = @builder.get_object("victoryquit").signal_connect("clicked") do
        quit
      end

      victoryNew = @builder.get_object("victorynew").signal_connect("clicked") do
        @game.reset
        @builder.get_object("victorybox").hide()
      end

      @game = Game.new 1
      @game.players = [Player.new('Player 1', Player::TYPE_HUMAN), Player.new('Computer', Player::TYPE_AI)]
      # Register observer
      @game.add_observer self, :update
      # Synchronize ui
      @game.sync

      # Buttons disabled initially.
      disable_buttons
      openSettings

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
    when Game::U_COMPLETED
      update_completed *args
    end
  end

  def update_completed(state,player)
    if state != Game::ONGOING
      disable_buttons
      @builder.get_object("victorybox").show()
      if state == Game::DRAW
        @builder.get_object("victoryplayer").set_markup("<span weight=\"bold\" foreground=\"#0097ff\">Game is a draw!</span>")
      else
        @builder.get_object("victoryplayer").set_markup("<span weight=\"bold\" foreground=\"#0097ff\">*#{player.name} has won!</span>")
      end
    else
      enable_buttons
    end
  end

  def enable_buttons
    1.upto(Game::WIDTH) { |i| 
      @builder.get_object("button" + i.to_s).sensitive = true
    }
  end

  def disable_buttons
    1.upto(Game::WIDTH) { |i| 
      @builder.get_object("button" + i.to_s).sensitive = false
    }
  end

  def update_board(row,col,piece)
    i = col + ((row)*Game::WIDTH) + 1
    @builder.get_object("image#{i}").pixbuf = Gdk::Pixbuf.new(image_for_piece(piece))
  end

  def update_turn(turn)
    @builder.get_object("turn").text = "Turn: #{turn}" 
  end

  def update_game(game)
    case game
    when Game::GAME_OTTO
      label = "Game Type: Otto"
    when Game::GAME_C4
      label = "Game Type: Connect 4"
    end
    @builder.get_object("game_type").text = label
  end

  def update_player(current,player)
    @builder.get_object("incoming").pixbuf = Gdk::Pixbuf.new(image_for_piece(@game.currentPlayer+1))
    @game.players.each_with_index do |player,i|
      label = @builder.get_object("player#{i+1}")
      desc = @builder.get_object("player#{i+1}desc")
      if current != i 
        label.text = "#{player.name}"
        desc.text = "Player Type: #{player.desc}"
      else
        label.set_markup("<span weight=\"bold\" foreground=\"#0097ff\">*#{player.name}</span>")
        desc.text = "Player Type: #{player.desc}"
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

    @builder.get_object("player1name").text = @game.players[0].name
    @builder.get_object("player2name").text = @game.players[1].name

    @builder.get_object("ai1").active = @game.players[0].type == Player::TYPE_AI 
    @builder.get_object("ai2").active = @game.players[1].type == Player::TYPE_AI
  end
  private 

  def saveSettings
    gameCombo = @builder.get_object("GameCombo")
    difficultyCombo = @builder.get_object("DifficultyCombo")
    game = gameCombo.active
    dif = difficultyCombo.active
    @game.game = game
    @game.difficulty = dif
    p1name = @builder.get_object("player1name")
    p2name = @builder.get_object("player2name")
    p1ai = @builder.get_object("ai1")
    p2ai = @builder.get_object("ai2")
    @game.players = [
      Player.new( p1name.text, p1ai.active? ? Player::TYPE_AI : Player::TYPE_HUMAN ),
      Player.new( p2name.text, p2ai.active? ? Player::TYPE_AI : Player::TYPE_HUMAN )
    ]
    @game.reset
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
  end  

  def quit
    Gtk.main_quit()
  end


end

controller = Controller.new

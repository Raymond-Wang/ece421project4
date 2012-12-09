#!/usr/bin/env ruby
require 'rubygems'
require 'gtk2'
require 'data_mapper'
require "pry"

require './init'
require "./error"
require "./models"
require "./client"

# Nicer access for our objects
class UI
  def initialize(builder)
    @builder = builder
  end

  def [](k)
    @builder.get_object(k)
  end
end

class Controller
  attr :glade

  def initialize
    if __FILE__ == $0
      Gtk.init
      @builder = Gtk::Builder::new
      @builder.add_from_file("c4.glade")
      @builder.connect_signals{ |handler| method(handler) }

      # Destroying the window will terminate the program
      @window = @builder.get_object("window1")
      @window.signal_connect( "destroy" ) { quit }
      
      @ui = UI.new @builder

      # The 'Quit' button will terminate the program
      menu = @ui["Quit"]
      menu.signal_connect( "activate" ) { quit }

      # The 'New' button will start a new game
      menu = @ui["New"]
      menu.signal_connect( "activate" ) { @game.reset }

      # The 'Settings' button will open a new window called settings
      settings = @ui["Settings"]
      settings.signal_connect( "activate" ) { open_settings }

      # The 'Settings' button will open a new window called settings
      about = @ui["About"]
      about.signal_connect( "activate" ) { openAbout() }

      # Keep it from destroying the dialog.
      @ui["dialog1"].signal_connect("delete_event"){ @ui["dialog1"].hide }

      # The 'OK' button in Settings will save the settings and close the window
      settingsOK = @ui["SettingsOK"]
      settingsOK.signal_connect( "clicked" ) { save_settings }

      # The 'Cancel' button in Settings will negate any changes to the settings and close the window
      settingsCancel = @ui["SettingsCancel"]
      settingsCancel.signal_connect( "clicked" ) { hide_settings }

      # Attach a signal to each button
      1.upto(Game::WIDTH) { |i| 
        @ui["button" + i.to_s].signal_connect("clicked") { button_clicked(i) }
      }

      victoryQuit = @ui["victoryquit"].signal_connect("clicked") do
        quit
      end
      
      @sem = Mutex.new
      @cv = ConditionVariable.new

      # The 'Cancel' button in Settings will negate any changes to the settings and close the window
      @network = @builder.get_object("network")
      @network.signal_connect( "clicked" ) do
        if @network.active?
          network_enable
        else
          network_disable
        end
      end

      @local_specific = {
        ai2: @ui["ai2"],
        player2name: @ui["player2name"]
      }
      
      @network_specific =  {
        host: @ui["host"],
        port: @ui["port"]
      }

      network_disable

      victoryNew = @ui["victorynew"].signal_connect("clicked") do
        @game.reset
        @ui["victorybox"].hide()
      end

      disable_buttons
      @window.show
      open_settings
      # Buttons disabled initially.
      
      
      # Used to coordinate handshake.
      @q = Queue.new
      Gtk.main()
    end
  end
  
  def network_enable
    @network.active = true
    @network_specific.each do |k,o|
      o.sensitive = true
    end
    @local_specific.each do |k,o|
      o.sensitive = false
    end
  end

  def network_disable
    @network.active = false
    @network_specific.each do |k,o|
      o.sensitive = false
    end
    @local_specific.each do |k,o|
      o.sensitive = true
    end
  end

  def update_ui(what,*args)
    case what
    when Game::U_BOARD
      update_ui_board *args
    when Game::U_RESET
      reset_board *args
    when Game::U_PLAYER
      update_ui_player *args
    when Game::U_TURN
      update_ui_turn *args
    when Game::U_GAME
      update_ui_game *args
    when Game::U_COMPLETED
      update_ui_completed *args
    end
  end

  def update_ui_completed(state,player)
    if state == Game::WIN || state == Game::DRAW
      @ui["victorybox"].show()
      if state == Game::DRAW
        @ui["victoryplayer"].set_markup("<span weight=\"bold\" foreground=\"#0097ff\">Game is a draw!</span>")
      else
        @ui["victoryplayer"].set_markup("<span weight=\"bold\" foreground=\"#0097ff\">*#{player} has won!</span>")
      end
    end
    toggle_buttons
  end

  def toggle_buttons
    if @game.can_move?
      enable_buttons
    else
      disable_buttons
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

  def update_ui_board(row,col,piece)
    i = col + ((row)*Game::WIDTH) + 1
    @ui["image#{i}"].pixbuf = Gdk::Pixbuf.new(image_for_piece(piece))
  end

  def update_ui_turn(turn)
    @builder.get_object("turn").text = "Turn: #{turn}" 
  end

  def update_ui_game(game)
    case game
    when Game::GAME_OTTO
      label = "Game Type: Otto"
    when Game::GAME_C4
      label = "Game Type: Connect 4"
    end
    @builder.get_object("game_type").text = label
  end

  def update_ui_player(currentPlayer)
    # TODO Distinction between network and single mode.
    toggle_buttons
    if @client.player.name != currentPlayer
      disable_buttons
    end

    piece = @game.current_piece
    @builder.get_object("incoming").pixbuf = Gdk::Pixbuf.new(image_for_piece(piece))
    
    i = 0
    @game.players.each_with_index do |player,x|
      if player.nil?
        binding.pry
        next
      end
      i = i + 1
      label = @ui["player#{i}"]
      desc = @ui["player#{i}desc"]
      if currentPlayer != player.name 
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

  def open_settings
    dialog = @ui["dialog1"]
    dialog.show
    dialog.present
    gameCombo = @ui["GameCombo"]
    difficultyCombo = @ui["DifficultyCombo"]

    @game ||= Game.create
    gameCombo.active=@game.game
    difficultyCombo.active=@game.difficulty

    if @game.players.length > 0 
      @ui["player1name"].text = @game.players[0].name
      @ui["ai1"].active = @game.players[0].type == Player::TYPE_AI 
    end
    if @game.players.length > 1
      @ui["player2name"].text = @game.players[1].name
      @ui["ai2"].active = @game.players[1].type == Player::TYPE_AI
    end

    @ui['host'].text = "192.168.1.130"
    @ui['port'].text = "50500"
  end
  private 

  def validate_solo
    errors = []
    if not @ui["player1name"].text.strip.length > 0
      if not @ui["ai1"].active?
        errors << "Player 1 must have a name."
      end
    end
    if not @ui["player2name"].text.strip.length > 0
      if not @ui["ai2"].active?
        errors << "Player 2 must have a name."
      end
    end
    if errors.length > 0
      error_dialog errors do
        @ui['dialog1'].present
      end
    end
    errors.length == 0
  end

  def validate_network
    errors = []
    if not @ui["player1name"].text.strip.length > 0
      errors << "Player must have a name."
    end
    if not @ui["host"].text.strip.length > 0
      errors << "Please specify a host."
    end
    if not @ui["port"].text.strip.length > 0
      errors << "Please specify a port."
    end
    if errors.length > 0
      error_dialog errors do
        @ui['dialog1'].present
      end
    end
    errors.length == 0
  end

  def error_dialog(messages,head="Oops...",&block)
      dialog(messages,head,Gtk::MessageDialog::ERROR,&block)
  end
  
  def info_dialog(messages,head="Waiting.",&block)
      dialog(messages,head,Gtk::MessageDialog::INFO,&block)
  end


  def dialog(messages,head,type,&block)
    dialog = Gtk::MessageDialog.new(@window,
      Gtk::Dialog::DESTROY_WITH_PARENT,type, 
      Gtk::MessageDialog::BUTTONS_CLOSE, head)
    # Coerce to array.
    messages = [*messages]
    dialog.set_secondary_text messages.join("\n")
    dialog.show_all
    if block_given?
      dialog.signal_connect "destroy", &block
    end
    # This is not intuitive at all. Run then destroy to show a dialog?
    dialog.run
    dialog.destroy
  end

  def begin_network
    return unless validate_network
    host = @network_specific[:host].text
    port = @network_specific[:port].text
    name = @network_specific[:port].text

    @greeted = ConditionVariable.new
    @player = Player.first_or_create( :name => @ui['player1name'].text )
    begin
      client = Client.new @player, @ui["host"].text, @ui["port"].text
      Thread.new do
        client.serve
      end
      @q << client.greet
      @client = client
    rescue Errno::EADDRINUSE, Errno::ECONNREFUSED, Errno::EHOSTUNREACH
      error_dialog "Could not connect to directory server."
    end
    show_games
  end

  def create_game
    @game = Game.create
    # Register observer
    @game.add_observer self, :update_ui
    @game.difficulty = @ui["DifficultyCombo"].active
    @game.game = @ui['GameCombo'].active
    @game.players << @player
    @player.save
    @game.save
    @client.game = @game
    Thread.new do
      @sem.synchronize do
        @q.pop
        @client.join @game.id
      end
    end
    # Synchronize ui
    @game.sync
    info_dialog "Waiting for a player..."
  end

  def open_game(id)
    game = Game.get(id)
    if not game
      error_dialog "Game no longer exists. Odd." 
    elsif game.players.length === 2 and not game.players.any? { |p| p.name == p1name }
      error_dialog "You didn't participate in this game."
    else
      @ui['window3'].hide
      @game = Game.get(id)
      @game.add_observer self, :update_ui
      @game.players << @player
      @player.save
      @game.save
      Thread.new do
        @sem.synchronize do
          @q.pop
          @client.game = @game
          @client.join @game.id
        end
      end
      @game.sync
      info_dialog "Waiting for a player..."
    end
  end

  def p1name
    @ui["player1name"].text
  end

  def begin_solo
    return unless validate_solo
    @game = Game.create

    @game.game = @ui["GameCombo"].active
    @game.difficulty = @ui["DifficultyCombo"].active
    p1name = @ui["player1name"]
    p2name = @ui["player2name"]
    p1ai = @builder.get_object("ai1")
    p2ai = @builder.get_object("ai2")
    @game.players << create_player(p2name.text, p2ai.active?)
    @game.players << create_player(p1name.text, p1ai.active?)
    @game.reset
    @game.start p1name.text

    # Register observer
    @game.add_observer self, :update_ui
    # Synchronize ui
    @game.sync
  end

  def create_player(name, ai)
    p = Player.first_or_create( :name => name )
    p.type = (ai ? Player::TYPE_AI : Player::TYPE_HUMAN)
    p
  end

  def save_settings
    if @network.active? and not validate_network
      return
    end
    if @network.active?
      begin_network
    else
      begin_solo
    end
    hide_settings
  end
  private

  def show_settings
    @ui['dialog1'].run
  end

  def hide_settings
    @ui["dialog1"].hide
  end
  private

  def openAbout
    about = @builder.get_object("window2")
    # How's this for an Easter egg? Use this to nuke the db ;)
    DataMapper.auto_migrate!
    about.show()
  end
  private
  
  def button_clicked(col)
    @client.place_tile(col-1)
  end  

  def quit
    Gtk.main_quit()
  end

  def open_games
    Game.all.select { |game| game.players.length == 1 }
  end

  def show_games
      window = @builder.get_object("window3")
      window.signal_connect( "destroy" ) { quit }
      
      treeview = @ui["serverlist"]
      liststore = @builder.get_object("liststore3")

      liststore.clear()

      games = open_games

      for item in games 
        iter = liststore.append
        liststore.set_value(iter, 0, item.game_label)
        if item.players.length > 0
          liststore.set_value(iter, 1, item.players.first.name)
        else
        end
        liststore.set_value(iter, 2, item.id)
      end

      @ui['joinbutton'].signal_connect "clicked" do
        @ui['window3'].hide
        if treeview.selection and treeview.selection.selected
          open_game treeview.selection.selected.get_value 2
        else
          error_dialog "You didn't select a game."
        end
      end

      @ui['createbutton'].signal_connect "clicked" do
        @ui['window3'].hide
        create_game
      end
      window.show
      window.present
  end
end

controller = Controller.new

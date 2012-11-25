#!/usr/bin/env ruby
require 'rubygems'
require 'gtk2'

class C4Glade
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
      1.upto(35) { |i| 
         @builder.get_object("button" + i.to_s).signal_connect("clicked") {button_clicked(i)};
      }

# Defines the setting for current game
# 0 - Connect 4
# 1 - OTTO TOOT
      @game = 0

# Defines the difficulty for current game
# 0 - Easy
# 1 - Medium
# 2 - Hard
      @difficulty = 0

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

require 'rubygems'
require 'data_mapper'
require 'gtk2'

  DataMapper::Logger.new($stdout, :debug)

  DataMapper.setup(:default, 'mysql://group4:YQupPp9E@mysqlsrv.ece.ualberta.ca:13010/group4')

  class Player
    include DataMapper::Resource
    property :name, String, :key => true
    property :elo, Integer
    has n, :games, :through => Resource
  end

  class Game
    include DataMapper::Resource
    property :id, Serial
    property :name, String
    has n, :players, :through => Resource
  end

  def getOpenGames
    games = Game.all
    games.each {|game|
      if game.players.length == 1
        game
      end
    }
  end

  DataMapper.auto_migrate! 

class Controller
  attr :glade

  def initialize
    if __FILE__ == $0
      Gtk.init
      @builder = Gtk::Builder::new
      @builder.add_from_file("c4.glade")
      @builder.connect_signals{ |handler| method(handler) }

      # Destroying the window will terminate the program
      window = @builder.get_object("window3")
      window.signal_connect( "destroy" ) { quit }
      
      liststore = @builder.get_object("liststore3")

      liststore.clear()

      lawton = Player.new
      lawton.attributes = {
        :name => 'Lawton',
        :elo => 564
      }

      game1 = Game.new
      game1.attributes = {
        :id => 1,
        :name => 'game1'
      }

      game1.players << lawton

      lawton.save
      game1.save

      games = getOpenGames

      iter = liststore.append
      liststore.set_value(iter, 0, "Connect 4")
      liststore.set_value(iter, 1, games[0].players[0].name)
      liststore.set_value(iter, 2, games[0].players[0].elo)

      window.show()
      Gtk.main()
    end
  end

end



controller = Controller.new

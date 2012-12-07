require 'rubygems'
require 'data_mapper'

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

  def adjustElo(winner, loser)
    expected = winner.elo.to_f / (winner.elo.to_f + loser.elo.to_f)
    winner.elo = winner.elo + 100**(1-expected)
    loser.elo = loser.elo - 100**(1-expected)
  end

  def getEmptyGames
    games = Game.all
    games.each {|game|
      if game.players.length == 0
        game
      end
    }
  end

  def getOpenGames
    games = Game.all
    games.each {|game|
      if game.players.length == 1
        game
      end
    }
  end

  def getGamesWithPlayer(player)
    games = Game.all
    games.each {|game|
      if game.players.include?(player)
        game
      end
    }
  end

  def getPlayersByElo
    Player.all(:order => [ :elo.desc ])
  end

  def getPlayerByName(name)
    Player.first(:name => name)
  end

  DataMapper.finalize
  DataMapper.auto_migrate! 

  ray = Player.new
  ray.attributes = {
    :name => 'Ray',
    :elo => 1000
  }

  jacob = Player.new
  jacob.attributes = {
    :name => 'Jacob',
    :elo => 1000
  }

  game1 = Game.new
  game1.attributes = {
    :id => 1,
    :name => 'game1'
  }

  game2 = Game.new
  game2.attributes = {
    :id => 2,
    :name => 'game2'
  }

  game3 = Game.new
  game3.attributes = {
    :id => 3,
    :name => 'game3'
  }

  game1.players << ray
  game1.players << jacob

  game2.players << ray
  game2.players << jacob

  adjustElo(jacob,ray)

  ray.save
  jacob.save

  game1.save
  game2.save
  game3.save

  pl = Player.first(:name => 'Jacob')
  pl2 = Player.first(:name => 'Ray')

  puts pl.inspect
  puts pl2.inspect

  games = getGamesWithPlayer(pl)
  games.each {|game| puts game.players[0].inspect}

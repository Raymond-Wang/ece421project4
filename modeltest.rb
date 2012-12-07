require "rubygems"
require "test/unit"
require "./models"
require "./init"

class ClientServerTest < Test::Unit::TestCase
  def teardown
    Player.all.destroy
    Game.all.destroy
  end

  def test_player_init
    jacob = Player.new 'Jacob', Player::TYPE_HUMAN
    raymond = Player.new 'Raymond', Player::TYPE_HUMAN
    jacob.save
    raymond.save

    game = Game.create 
    game.players << jacob
    game.players << raymond
    game.save

    james = Player.new 'James', Player::TYPE_HUMAN
    ravi = Player.new 'Ravi', Player::TYPE_HUMAN
    james.save
    ravi.save

    game2 = Game.create
    game2.players << james
    game2.players << ravi
    game2.save
  end

  def test_empty_init
    game = Game.create game: Game::GAME_OTTO
    game.save
  end
end


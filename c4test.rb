require "test/unit"
require "./c4.rb"

class C4Test < Test::Unit::TestCase

  def setup
    @jacob = Player.new 'Jacob', Player::TYPE_AI
    @raymond = Player.new 'Raymond', Player::TYPE_HUMAN
  end

  def test_next_turn
    game = Game.new 1
    game.players = [@jacob,@raymond]
    game.next_turn
    assert_equal 1, game.currentPlayer
    game.next_turn
    assert_equal 0, game.currentPlayer
    game.next_turn
    assert_equal 1, game.currentPlayer
  end

  def test_place_tile
    game = Game.new 1
    game.players = [@jacob,@raymond]

    1.upto(Game::HEIGHT) { |i|
      assert game.place_tile(1), "Tile should be placeable"
    }
    # Should now be full and returning false.
    assert_equal false, game.place_tile(1)
    assert_equal false, game.place_tile(1)
    assert_equal false, game.place_tile(1)
  end

  def test_indices
    game = Game.new 1
    assert_equal [0,0], game.indices(1)
    assert_equal [0,1], game.indices(2)
    assert_equal [1,0], game.indices(8)
    assert_equal [5,6], game.indices(35)
  end

end

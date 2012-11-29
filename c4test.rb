require "test/unit"
require "./c4.rb"

class DummyStrategy
  def status
    return Game::ONGOING
  end
end

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

  # TODO next_tile and others should likely be private.
  def test_next_tile
    game = Game.new 1
    
    h = Game::HEIGHT-1
    assert_equal [h,0], game.next_tile(0)
    game.board[h][0] = 1

    h = h - 1
    assert_equal [h,0], game.next_tile(0)
    game.board[h][0] = 1

    h = h - 1
    assert_equal [h,0], game.next_tile(0)
    game.board[h][0] = 1
  end

  def test_place_tile
    game = Game.new 1
    game.players = [@jacob,@raymond]
    game.instance_eval do
      @strategy = DummyStrategy.new
    end
    (Game::HEIGHT-1).downto(0).each { |i|
      assert game.place_tile(3), "Tile should be placeable"
      assert_not_equal nil, game.board[i][3]
    }
    # Should now be full and returning false.
    assert_equal false, game.place_tile(3)
    assert_equal false, game.place_tile(3)
    assert_equal false, game.place_tile(3)
    assert_equal false, game.place_tile(3)
    assert_equal false, game.place_tile(3)
  end

  def test_indices
    game = Game.new 1
    assert_equal [0,0], game.indices(1)
    assert_equal [0,1], game.indices(2)
    assert_equal [1,0], game.indices(8)
    assert_equal [5,6], game.indices(35)
  end

  def test_reset
    game = Game.new 2, [@jacob, @raymond]
    game.instance_eval do
      @strategy = DummyStrategy.new
    end
    assert_equal 1, game.turn
    game.place_tile(0)
    assert_equal 2, game.turn
    game.place_tile(0)
    assert_equal 3, game.turn
  end

end

require "test/unit"
require "./c4.rb"

class StrategyTest < Test::Unit::TestCase

  def setup
    @jacob = Player.new 'Jacob', Player::TYPE_AI
    @raymond = Player.new 'Raymond', Player::TYPE_HUMAN
  end

  def test_vertical_win
    game = Game.new 2, [@raymond,@jacob]
    game.board[0][0] = 2
    game.board[1][0] = 2
    game.board[2][0] = 2
    game.board[3][0] = 2
    assert_equal Strategy::P2_WIN, game.status
  end

  def test_vertical_win_2
    game = Game.new 2, [@raymond,@jacob]
    game.board[1][0] = 2
    game.board[2][0] = 2
    game.board[3][0] = 2
    game.board[4][0] = 2
    assert_equal Strategy::P2_WIN, game.status
  end

  def test_c4_ai_win
    game = Game.new 2
    game.players = [@raymond,@jacob]
    game.currentPlayer = 1
    game.board[5][0] = 2
    game.board[5][1] = 2
    game.board[5][2] = 2
    assert_equal 3, game.move
  end

  def test_c4_ai_prevent_win
    game = Game.new 2
    game.players = [@raymond,@jacob]
    game.currentPlayer = 1
    game.board[5][0] = 1
    game.board[5][1] = 1
    game.board[5][2] = 1
    assert_equal 3, game.move
  end

  def test_c4_ai_feed_win
    game = Game.new 2
    game.players = [@raymond,@jacob]
    game.currentPlayer = 1
    game.board[5][0] = 2
    game.board[5][1] = 1
    game.board[5][2] = 2
    game.board[4][0] = 1
    game.board[4][1] = 1
    game.board[4][2] = 1
    assert_not_equal 3, game.move
  end

  def test_ot_ai_win
    game = Game.new 2
    game.game = Game::GAME_OTTO
    game.players = [@raymond,@jacob]
    game.currentPlayer = 1
    game.board[5][0] = 2
    game.board[5][1] = 1
    game.board[5][2] = 1
    assert_equal 3, game.move
  end

  def test_ot_ai_prevent_win
    game = Game.new 2
    game.game = Game::GAME_OTTO
    game.players = [@raymond,@jacob]
    game.currentPlayer = 1
    game.board[5][0] = 1
    game.board[5][1] = 2
    game.board[5][2] = 2
    assert_equal 3, game.move
  end

  def test_ot_ai_feed_win
    game = Game.new 2
    game.game = Game::GAME_OTTO
    game.players = [@raymond,@jacob]
    game.currentPlayer = 1
    game.board[5][0] = 1
    game.board[5][1] = 2
    assert_not_equal 2, game.move
  end

end

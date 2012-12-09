require "test/unit"
require "./server"
require "./client"
require "./util"
require "./models"
require "./dummygame"

Util.debug_conf /.*/

class ClientServerTest < Test::Unit::TestCase
  def setup
    # For testing I want deterministic ids.
    DataMapper.repository(:default).adapter.execute('SET FOREIGN_KEY_CHECKS = 0')
    DataMapper.repository(:default).adapter.execute('TRUNCATE TABLE `players`')
    DataMapper.repository(:default).adapter.execute('TRUNCATE TABLE `games`')
    DataMapper.repository(:default).adapter.execute('SET FOREIGN_KEY_CHECKS = 1')
  end

  def test_existing
    ip = Util.get_ip
    server = GameServer.new 50500, ip
    Thread.new do
      server.serve
    end

    james = Player.create name: 'James', type: Player::TYPE_HUMAN
    ravi = Player.create name: 'Ravi', type: Player::TYPE_HUMAN
    james.save
    ravi.save

    game = Game.create
    game.players << james
    game.players << ravi

    # Change this after on purpose.
    game.game = Game::GAME_C4
    game.save
    
    assert_equal 1, game.id
    assert_equal Game::GAME_C4, game.game

    #c_jacob = Client.new jacob, ip, 50500
    c_james = Client.new james, ip, 50500
    c_james.game = Game.get(game.id)
    c_james.greet
    c_james.serve

    c_ravi = Client.new ravi, ip, 50500
    c_ravi.game = Game.get(game.id) 
    c_ravi.greet
    c_ravi.serve

    c_ravi.join game.id
    assert_equal Game::WAITING, c_ravi.game.state
    assert_equal Game::GAME_C4, c_ravi.game.game
    assert_equal 1, c_ravi.game.id
    
    c_james.join game.id
    assert_equal Game::GAME_C4, c_james.game.game

    # Wait for clients to sync
    # At this join we should have started the game.
    sleep 0.5 

    assert_equal Game::ONGOING, c_ravi.game.state

    assert_equal 1, game.id
    assert_equal game.id, c_ravi.game.id
    assert_equal game.id, c_james.game.id

    assert_equal Game.blank_board, c_ravi.game.board
    assert_equal Game.blank_board, c_james.game.board

    # The first player to join the game will be the first player to 
    # go. This actually isn't enforced through the code but works coincidentall
    # because of the way the database is queried and how associations are
    # added.
    assert_equal "James", c_james.game.currentPlayer

    c_james.place_tile 0
    sleep 1 

    assert_equal 2, c_james.game.board[5][0]
    assert_equal 2, c_ravi.game.board[5][0]
    assert_equal Game::ONGOING, c_james.game.state
    assert_equal Game::ONGOING, c_ravi.game.state

    c_ravi.place_tile 0
    sleep 0.2
    assert_equal 1, c_james.game.board[4][0]
    assert_equal 1, c_ravi.game.board[4][0]
    assert_equal Game::ONGOING, c_james.game.state
    assert_equal Game::ONGOING, c_ravi.game.state

    assert_equal 3, c_james.game.turn
    assert_equal 3, c_ravi.game.turn
    assert_equal "James", c_james.game.currentPlayer
    assert_equal "James", c_ravi.game.currentPlayer
  end

end

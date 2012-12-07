require "test/unit"
require "./server"
require "./client"
require "./util"
require "./models"
require "./dummygame"

Util.debug_conf /.*/

# Some hooks for our tests.
$test_q = Queue.new

class Game < Model
  after :save do |o|
    $test_q << true
    Util.biglog "SAVED: #{o.id}"
  end
end

class ClientServerTest < Test::Unit::TestCase
  def setup
    # For testing I want deterministic ids.
    DataMapper.repository(:default).adapter.execute('SET FOREIGN_KEY_CHECKS = 0')
    DataMapper.repository(:default).adapter.execute('TRUNCATE TABLE `players`')
    DataMapper.repository(:default).adapter.execute('TRUNCATE TABLE `games`')
    DataMapper.repository(:default).adapter.execute('SET FOREIGN_KEY_CHECKS = 1')
  end

  def test_simple
    ip = Util.get_ip
    game = DummyGame.new
    g_jacob = DummyGame.new

    Util.debug "Gamserver"
    server = GameServer.new game, 1234
    Thread.new do
      server.serve
    end
    sleep 0.2
    Util.debug "Client"
    clientA = Client.new g_jacob, "jacob", ip, 1234
    sleep 0.2
    Util.debug "Greeting"
    clientA.greet
    Util.debug "Greeting Done"
  end

  def test_multiplexing
    ip = Util.get_ip
    game = DummyGame.new
    g_jacob = DummyGame.new
    g_ray = DummyGame.new

    server = GameServer.new 2000, ip

    Thread.new do
      server.serve
    end

    log = []

    sem = Mutex.new

    # Let the server ramp up
    sleep 1.0

    start = Time.now

    last = Thread.new do
      clientA = Client.new "jacob", ip, 2000
      clientA.wait 3
      sem.synchronize do
        log.push "Client A"
      end
    end

    Thread.new do
      clientA = Client.new "ray", ip, 2000
      clientA.wait 2 
      sem.synchronize do
        log.push "Client B"
      end
    end

    # Should be the last one to complete.
    last.join

    assert_equal "Client A", log[1]
    assert_equal "Client B", log[0]
    # Timing. Should take less than 3.5 seconds. If it takes more than 6
    # The server isn't multiplexing.
    assert_operator 3.5, :>, (Time.now - start)
  end

  def test_place_tile
    ip = Util.get_ip
    game = DummyGame.new
    g_jacob = DummyGame.new
    g_ray = DummyGame.new

    server = GameServer.new 50500, ip
    Thread.new do
      server.serve
    end

    jacob, ray = nil, nil
    t_jacob = Thread.new do
      jacob = Client.new g_jacob, "jacob", ip, 50500
    end

    t_ray = Thread.new do
      ray = Client.new g_ray, "ray", ip, 50500
    end

    t_jacob.join
    t_ray.join

    Util.debug "Starting game."
    server.start "jacob"
    Util.debug "Game started."
    
    # Let everyone synch.
    sleep 0.2

    assert_equal 1, server.game.turn
    assert_equal 1, jacob.game.turn
    assert_equal 1, ray.game.turn

    Util.debug "Placing tile."
    jacob.place_tile 0
    Util.debug "Tile placed."

    # Let everyone synch.
    sleep 0.2 

    assert_equal 2, server.game.turn
    assert_equal 2, jacob.game.turn
    assert_equal 2, ray.game.turn

    # Let everyone synch.
    sleep 0.2

    assert_equal "ray", jacob.game.currentPlayer
    assert_equal "ray", jacob.game.currentPlayer
    assert_equal "ray", server.game.currentPlayer
  end

  def test_server_live_model
    jacob = Player.new 'Jacob', Player::TYPE_HUMAN
    raymond = Player.new 'Raymond', Player::TYPE_HUMAN
    jacob.save
    raymond.save

    ip = Util.get_ip

    server = GameServer.new 50500, ip
    Thread.new do
      server.serve
    end

    jacob, ray = nil, nil
    c_jacob = Client.new "jacob", ip, 50500
    c_ray = Client.new "ray", ip, 50500

    # Create a game on the server.
    c_jacob.join -1 
  end

  def test_new_game
    ip = Util.get_ip
    server = GameServer.new 50500, ip
    Thread.new do
      server.serve
    end

    c_jacob = Client.new "jacob", ip, 50500
    c_jacob.create Game::GAME_OTTO
    assert_equal true, test_q.pop
  end

  def test_existing
    ip = Util.get_ip
    server = GameServer.new 50500, ip
    Thread.new do
      server.serve
    end

    jacob = Player.new 'Jacob', Player::TYPE_HUMAN
    james = Player.new 'James', Player::TYPE_HUMAN
    ravi = Player.new 'Ravi', Player::TYPE_HUMAN
    james.save
    ravi.save

    game = Game.create
    game.players << james
    game.players << ravi
    game.save

    binding.pry

    c_jacob = Client.new jacob, ip, 50500
    c_james = Client.new james, ip, 50500
    c_ravi = Client.new ravi, ip, 50500

    c_ravi.join game.id
    c_james.join game.id

    assert_equal 1, game.id
    assert_equal game.id, c_ravi.game.id
    assert_equal game.id, c_james.game.id
  end

end

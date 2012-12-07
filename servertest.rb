require "test/unit"
require "./server"
require "./client"
require "./util"
require "./dummygame"

Util.debug_conf /.*/

class ClientServerTest < Test::Unit::TestCase
  def test_simple
    ip = Util.get_ip
    game = DummyGame.new
    g_jacob = DummyGame.new

    Util.debug "Gamserver"
    server = GameServer.new game, 1234
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

    Thread.new do
      gameserver = GameServer.new game, ip 
    end

    log = []

    sem = Mutex.new

    # Let the server ramp up
    sleep 1.0

    start = Time.now

    last = Thread.new do
      clientA = Client.new g_jacob, "jacob", ip, 2000
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

    server = nil
    t_server = Thread.new do
      server = GameServer.new game, 50500, ip
    end

    jacob, ray = nil, nil
    t_jacob = Thread.new do
      jacob = Client.new g_jacob, "jacob", ip, 50500
    end

    t_ray = Thread.new do
      ray = Client.new g_ray, "ray", ip, 50500
    end

    t_server.join
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

    game = Game.new 1, [jacob,raymond]
    game.save

    james = Player.new 'James', Player::TYPE_HUMAN
    ravi = Player.new 'Ravi', Player::TYPE_HUMAN
    james.save
    ravi.save

    game2 = Game.new 1, [james,ravi]
    game2.save

    ip = Util.get_ip

    server = nil
    t_server = Thread.new do
      server = GameServer.new game, 50500, ip
    end

    jacob, ray = nil, nil
    t_jacob = Thread.new do
      jacob = Client.new g_jacob, "jacob", ip, 50500
    end

    t_ray = Thread.new do
      ray = Client.new g_ray, "ray", ip, 50500
    end

    t_server.join
    t_jacob.join
    t_ray.join
  end
end

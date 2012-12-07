
def test_server_client
  # Happy Day Scenario:
  # 1. Server created.
  # 2. First client (A) connects to server, provides a valid name.
  # 3. First client (A) starts a new game
  # 4. Second client (B) connects to server.
  # 5. Client B selects "Jacob's Game"
  # 6. The game starts. We roll the rice to see who goes first.
  # 7. The players are assigned tokens.

  @board = Array.new 
  (0...Game.HEIGHT).each do |r|
    board[r] = Array.new
    (0...Game.WIDTH).each do |c|
      @board[r][c] = nil
    end
  end
  
  @gameserver = GameServer.new 2000..2005

  # This constructor also implicitly creates a new user with the name "jacob"
  @clientA = GameClient.new gamerserver.port, 'jacob'
  @clientA.create_game "Jacob's Game"

  @clientB = GameClient.new gamerserver.port, 'ray'

  # Gameserver.current is our current player.
  assert_equals 'jacob', @gameserver.game.current.name
  # Gameserver.next is our next player.
  assert_equals 'ray', @gameserver.game.next.name

  # Turns the game servers turn. Should proxy to it's internal game, 
  # which we don't want to touch for reasons. 
  assert_equals 1, @gamserver.game.turn

  assert_equals @board, @gameserver.game.board
  assert_equals @board, @clientA.game.board
  assert_equals @board, @clientB.game.board

  @clientA.place_tile 5
  
  # Wait for the event, necessary for testing. Potentially useful otherwise.
  @clientB.wait_for :place_tile
  @gameserver.wait_for :place_tile

  # First player always has the '1' token by convention.
  @board[Game.Height-1][5] = 1

  assert_equals @board, @gameserver.game.board
  assert_equals @board, @clientA.game.board
  assert_equals @board, @clientB.game.board
end


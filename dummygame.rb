require "pry"

class DummyGame
  attr_accessor :turn, :currentPlayer
  def initialize
    @currentPlayer = nil
    @turn = 1
    @players = []
    @sem = Mutex.new
  end

  def start(player)
    @sem.synchronize do
      @currentPlayer = player
      @turn = 1
    end
  end

  def place_tile(col)
    @sem.synchronize do
      @turn = @turn + 1
      if @players[0] == @currentPlayer
        @currentPlayer = @players[1]
      else
        @currentPlayer = @players[0]
      end
    end
  end

  def add_player(player)
    @sem.synchronize do
      @players << player
    end
  end

  def set_current(player)
    @sem.synchronize do
      @currentPlayer = player
    end
  end
end


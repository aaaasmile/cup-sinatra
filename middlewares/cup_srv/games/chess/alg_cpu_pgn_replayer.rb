#file: alg_cpu_pgn_replayer.rb

class AlgCpuPgnReplayer
  def initialize(player, coregame, timeout_handler)
    @timeout_handler = timeout_handler
    @alg_player = player
    @log = Log4r::Logger["coregame_log"]
    @core_game = coregame
  end
  
  def parse_pgn_file(filename)
  end
  
  def onalg_new_match(players_info)
    @opponent_name = opponent_name
    @alg_color = your_color
  end
  
  def onalg_have_to_move(player)
    if player == @alg_player
      @log.debug("onalg_have_to_move cpu alg: #{@alg_player.name}")
      if @timeout_handler
        @timeout_handler.registerTimeout(@option_gfx[:timeout_haveplay], :onTimeoutAlgorithmHaveToPlay, self)
        # suspend core event process until timeout
        # this is used to sloow down the algorithm play
        @core_game.suspend_proc_gevents
        
      else
        # no wait for gfx stuff, continue immediately to play
        alg_make_move
      end
      # continue on onTimeoutHaveToPlay
    end 
  end
  
  ##
  # onTimeoutHaveToPlay: after wait a little for gfx purpose the algorithm make a move
  def onTimeoutAlgorithmHaveToPlay
    alg_make_move
    # restore event process
    @core_game.continue_process_events if @core_game
  end
  
  def alg_make_move
    
  end
  
  # color: :white :black
  # start_x, start_y, end_x, end_y : integer 0..7
  def onalg_player_has_moved(player,move)
    if player != @alg_player
      
    end
  end
  
end


if $0 == __FILE__
end
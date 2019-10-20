#bot used to check restart feature

$:.unshift(File.expand_path( File.join(File.dirname(__FILE__), '..')))

require 'bot_base'
require 'base/core/core_game_base'


class TestRestartViewBot < GameBasebot
  
  def initialize()
    @restart_erq = false
    super()
  end
  
  def onalg_new_giocata(carte_player)
    
    @log.debug("Test case resign the game")
    @net_controller.resign_game_cmd 
  end
  
  def onalg_game_end(best_pl_segni)
    @log.debug("Game end, stay on the table")
    @alg_auto_player.onalg_game_end(best_pl_segni)
    if !@restart_erq
      @restart_erq = true
      @net_controller.restart_game_cmd
    end
  end
  
end
#file: bot_base.rb
# base stuff for a bot game 

$:.unshift(File.expand_path( File.join(File.dirname(__FILE__), '..')))
require 'base/core/core_game_base'

require 'games/briscola/alg_cpu_briscola'
require 'games/briscola/core_game_briscola'

require 'games/briscolone/alg_cpu_briscolone'
require 'games/briscolone/core_game_briscolone'

require 'games/mariazza/alg_cpu_mariazza'
require 'games/mariazza/core_game_mariazza'

require 'games/tressette/core_game_tressette'
require 'games/tressette/alg_cpu_tressette'

require 'games/tressettein4/core_game_tressettein4'
require 'games/tressettein4/alg_cpu_tressettein4'

require 'games/spazzino/alg_cpu_spazzino'
require 'games/spazzino/core_game_spazzino'

require 'games/scopetta/alg_cpu_scopetta'
require 'games/scopetta/core_game_scopetta'

require 'games/tombolon/alg_cpu_tombolon'
require 'games/tombolon/core_game_tombolon'


##
# Base stuff to handle all callbacks from remote server
# Simulate the gfx class
class GameBasebot <  AlgCpuPlayerBase
  attr_accessor :net_controller, :join_game
  attr_reader :nal_client_gfx_name
  
  def initialize()
    # logger for debug
    @log = Log4r::Logger.new("coregame_log::GameBasebot") 
    @core_game = nil
    @player_robot = nil
    @net_controller = nil
    @autoplayer_name = ''
    @nal_client_gfx_name = 'NalClientGfx'
    @alg_auto_player = nil
    @join_game = false
    @wait_time_opt = { :enabled => true, :havetoplay_time => 0.600}
  end
  
  # alg_name_class: e.g. 'AlgCpuTressette'
  # core_name_class: e.g. 'CoreGameTressette'
  # opt_game_keysym: e.g. :tressette_game
  def set_game_info(core_name_class, alg_name_class, opt_game_keysym, nalgfx_name, bot_name)
    @core_name_class = core_name_class
    @alg_name_class = alg_name_class
    @opt_game_keysym = opt_game_keysym
    @nal_client_gfx_name = nalgfx_name
    @robot_name = bot_name
  end
  
  def create_instance_core()
    return eval(@core_name_class).new
  end
  
  def create_instance_alg(player, core)
    return eval(@alg_name_class).new(player, core, nil)
  end
  
  def leave_on_less_players?()
    return @core_game.leave_on_less_players?
  end
  
  def start_new_game(players, options)
    @core_game = options[:netowk_core_game]
    @core_game.set_custom_core( create_instance_core() )
    @core_game.custom_core.create_deck
    @log.debug "using network  core game and custom core"
    #p options[:wait_time_info]
    if options[:wait_time_info]
      @wait_time_opt = options[:wait_time_info]
    end 
    players.each do |player|
      if player.name == @robot_name
        # local player  is the robot
        @alg_auto_player = create_instance_alg(player, @core_game)
        @player_robot = player
        @autoplayer_name = player.name
        if options[@opt_game_keysym] and options[@opt_game_keysym][:alg_level]
          @alg_auto_player.level_alg =  options[@opt_game_keysym][:alg_level]
        end
        @log.debug("Created auto player for the robot #{@robot_name}")
      else
        # remote player
      end
    end
    @core_game.gui_new_match(players)
  end
  
  def onalg_player_cardsnot_allowed(player, cards)
    @alg_auto_player.onalg_player_cardsnot_allowed(player, cards)
  end
  
  def onalg_player_has_changed_brisc(player, card_briscola, card_on_hand)
    @alg_auto_player.onalg_player_has_changed_brisc(player, card_briscola, card_on_hand)
  end
  
  def onalg_new_mazziere(player)
    @alg_auto_player.onalg_new_mazziere(player)
  end
  
  def onalg_player_has_getpoints(player, points)
    @alg_auto_player.onalg_player_has_getpoints(player, points)
  end
  
  def onalg_player_pickcards(player, cards_arr)
    @alg_auto_player.onalg_player_pickcards(player, cards_arr)
  end
  
  def onalg_player_has_declared(player, name_decl, points)
    @alg_auto_player.onalg_player_has_declared(player, name_decl, points)
  end
  
  def onalg_player_has_taken(player, cards)
    @alg_auto_player.onalg_player_has_taken(player, cards)
  end
  
  def onalg_game_end(best_pl_segni)
    @log.debug("Game end")
    @alg_auto_player.onalg_game_end(best_pl_segni)
    if @join_game
      @log.debug("Join robot on game end leave the table")
      @net_controller.leave_table_cmd
    end
  end
  
  def onalg_giocataend(best_pl_points)
    @alg_auto_player.onalg_giocataend(best_pl_points)
     # continue the game
    @core_game.gui_new_segno
  end
  
  def onalg_have_to_play(player,command_decl_avail)
    if @wait_time_opt[:enabled] == true
      #p 'sleep ...'
      sleep @wait_time_opt[:havetoplay_time]
    end 
    @alg_auto_player.onalg_have_to_play(player,command_decl_avail)    
  end
  
  def onalg_manoend(player_best, carte_prese_mano, punti_presi)
    @alg_auto_player.onalg_manoend(player_best, carte_prese_mano, punti_presi)
  end
  
  def onalg_newmano(player)
    @alg_auto_player.onalg_newmano(player)
  end
  
  def onalg_new_giocata(carte_player)
    @alg_auto_player.onalg_new_giocata(carte_player)
  end
  
  def onalg_new_match(players)
    @alg_auto_player.onalg_new_match(players)
  end
  
  def onalg_pesca_carta(carte_player)
    @alg_auto_player.onalg_pesca_carta(carte_player)
  end
  
  def onalg_player_has_played(player, lbl_card)
    @alg_auto_player.onalg_player_has_played(player, lbl_card)
  end
  
  def player_ready_to_start(user_name)
    # player want to restart the game
    @log.debug "#{user_name} is ready to restart"
    if @autoplayer_name != user_name
      @net_controller.restart_game_cmd
    end
  end
  
  def player_leave(user_name)
  end
  
  def do_core_process
    @core_game.process_only_one_gevent if @core_game
  end
  
  
end #end GameBasebot
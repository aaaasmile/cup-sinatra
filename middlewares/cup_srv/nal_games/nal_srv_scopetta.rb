# file: nal_srv_scopetta.rb
# Network abstraction layer on server for game scopetta

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'nal_srv_base'
require File.dirname(__FILE__)  + '/../base/core/core_game_base'
require File.dirname(__FILE__)  + '/../games/scopetta/core_game_scopetta'


module MyGameServer
  include Log4r
##
# Instance used by server to manage the scopetta core game  
class NALServerCoreGameScopetta < NalServerCoreBase
   
  def initialize(ix, dir_log)
    super("scopetta2p", ix, dir_log)
    @log = Log4r::Logger["coregame_log"] 
    ## core scopetta
    ## use here the same name as game_info.yaml
    @name_core_game = :scopetta_game
    ## NAL_Srv_SpazzAlgo is the nal for all scopa similar games
    @nal_algorithm_name = 'NAL_Srv_SpazzAlgo' 
    @gamename_indb = 'Scopetta'
    @core_game_name =  'CoreGameScopetta'
  end
  
  ##
  # Check custom options if they are on range. If not set it to default.
  def check_option_range
    point_win = @options_for_core_game["target_points"]
    if point_win > 31
      @options_for_core_game["target_points"] = 31
    end
  end
  
  ##
  # Provides options that are sent over the network. Usually on onalg_new_match.
  def get_options_fornewmatch
    opt = {}
    opt[:target_points] = @options_for_core_game["target_points"]
    opt[:vale_napola] = @options_for_core_game["vale_napola"]
    return opt
  end
  
  ##
  # Update the db with the new score
  def update_ranking
    result = @core_game.points_curr_match_sorted
    winner_info = result[0]
    loser_info = result[1]
    @log.info("Update the db for user #{winner_info[0]} and #{loser_info[0]}")
    #winner
    user_name = winner_info[0]
    punti_winner = winner_info[1]
    user_id = @players_indb[user_name]
    if user_id
      classitem = @db_connector.find_or_create_classifica(@gamename_indb, user_id) if @db_connector
      if classitem
        classitem.score = check_for_nullscore(classitem.score)
        classitem.score += 10
        classitem.match_won += 1
        classitem.tot_matchpoints += punti_winner
        tot = classitem.match_won + classitem.match_losed
        classitem.match_percent = (classitem.match_won * 100) / tot   
        
        classitem.save(@db_connector.active_pg_conn)
      end
    else
      #@log.error "User id not found for username #{user_name}"
      raise_err_usernotfound(user_name)
    end
    #loser
    user_name = loser_info[0]
    punti_loser = loser_info[1]
    user_id = @players_indb[user_name]
    if user_id
      classitem = @db_connector.find_or_create_classifica(@gamename_indb, user_id) if @db_connector
      if classitem
        classitem.score = check_for_nullscore(classitem.score)
        classitem.score -= 8
        classitem.match_losed += 1
        tot = classitem.match_won + classitem.match_losed
        classitem.match_percent = (classitem.match_won * 100)/ tot
        classitem.tot_matchpoints += punti_loser
        
        classitem.save(@db_connector.active_pg_conn)
      end
    else
      raise_err_usernotfound(user_name)
    end
  end
  
end #end class NALServerCoreGameScopetta



end #end module MyGameServer

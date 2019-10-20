# file: nal_srv_mariazza.rb
# Network abstraction layer on server for game mariazza

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'nal_srv_base'
require File.dirname(__FILE__)  + '/../base/core/core_game_base'
require File.dirname(__FILE__)  + '/../games/briscolone/core_game_briscolone'


module MyGameServer
  include Log4r
##
# Instance used by server to manage the briscolone core game  
class NALServerCoreGameBriscolone < NalServerCoreBase
  
  def initialize(ix, dir_log)
    super("briscolone", ix, dir_log)
    @log = Log4r::Logger["coregame_log"]  
    @core_game_name =  'CoreGameBriscolone'
    @name_core_game = :briscolone_game
    @gamename_indb = 'Briscolone'
  end
  
  ##
  # Provides options exported on the network
  def get_options_fornewmatch
    opt = {}
    opt[:target_points_segno] = @options_for_core_game["target_points_segno"]
    opt[:num_segni_match] = @options_for_core_game["num_segni_match"]
    return opt
  end
  
  ##
  # Check custom options if they are on range. If not set it to default.
  def check_option_range
    point_win = @options_for_core_game["target_points_segno"]
    num_segni = @options_for_core_game["num_segni_match"]
    if point_win != 61
      @options_for_core_game["target_points_segno"] = 61
    end
    if num_segni < 1 and num_segni > 5
      @options_for_core_game["num_segni_match"] = 1
    end
  end
 
  
  ##
  # Update the db with the new score
  def update_ranking
    result = @core_game.segni_curr_match_sorted
    winner_info = result[0]
    loser_info = result[1]
    @log.info("Update the db for user #{winner_info[0]} and #{loser_info[0]}")
    #winner
    user_name = winner_info[0]
    num_segni = winner_info[1]
    user_id = @players_indb[user_name]
    if user_id
      classitem = @db_connector.find_or_create_classifica(@gamename_indb, user_id) if @db_connector
      if classitem
        classitem.score = check_for_nullscore(classitem.score)
        classitem.score += 10
        classitem.match_won += 1
        classitem.legs_won +=  winner_info[1] if winner_info[1] > 0
        classitem.legs_losed +=  loser_info[1] if loser_info[1] > 0
        tot = classitem.match_won + classitem.match_losed
        classitem.match_percent = (classitem.match_won * 100 )/ tot
        
        classitem.save(@db_connector.active_pg_conn)
      end
    else
      @log.error "User id not found for username #{user_name}"
    end
    #loser
    user_name = loser_info[0]
    num_segni = loser_info[1]
    user_id = @players_indb[user_name]
    if user_id
      classitem = @db_connector.find_or_create_classifica(@gamename_indb, user_id) if @db_connector
      if classitem
        classitem.score = check_for_nullscore(classitem.score)
        classitem.score -= 8
        classitem.match_losed += 1
        classitem.legs_won +=  loser_info[1] if loser_info[1] > 0
        classitem.legs_losed +=  winner_info[1] if winner_info[1] > 0
        tot = classitem.match_won + classitem.match_losed
        classitem.match_percent = (classitem.match_won * 100) / tot 
        
        classitem.save(@db_connector.active_pg_conn)
      end
    else
      @log.error "User id not found for username #{user_name}"
    end
  end
 
end #end class NALServerCoreGameBriscolone



end #end module MyGameServer

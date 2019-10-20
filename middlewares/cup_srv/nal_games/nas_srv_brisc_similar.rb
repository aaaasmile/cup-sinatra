# file: nas_srv_brisc_similar.rb
# generic file for briscola and similar games


require 'rubygems'
require 'nal_srv_base'

module MyGameServer

class NALServerCoreBriscSimilar < NalServerCoreBase
  def initialize(name, ix)
    super(name, ix)
    @log = Log4r::Logger["coregame_log"] 
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
  
end

end
# file: nal_srv_algorithm.rb
# Network abstraction layer on server for algorithm callbacks

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'json'
require 'base/core/core_game_base'

module MyGameServer

######################################### 
###            NAL_Srv_Algorithm
#########################################  

##
# Abstraction layer for player algorithm. In this case we have only 
# remap algorithm core callbacks to remote socket communication (S ---> C)
# This class is used on briscola and similar games. For spazzino and 
# similar games we need another specialized class (see below).
# Each player becomes assigned a new instance of NAL_Srv_Algorithm
class NAL_Srv_Algorithm
  
  attr_accessor :name_core_game
  
  def initialize(conn,  game_inprog)
    # CuperativaUserConn instance
    @player_conn = conn
    # holds the name for the game core class. e.g. "mariazza"
    @name_core_game = nil
    # Nal server instance, like NALServerCoreGameMariazza
    @nal_srv = game_inprog.nal_server
    @log = Log4r::Logger["coregame_log"] 
    # index of the game
    @ix_game = game_inprog.ix_game
    # game in progress instance
    @game_inprog = game_inprog
  end
  
  ############### implements methods of AlgCpuPlayerBase
  
  def onalg_new_match(players)
    #name_arr = ["#{@name_core_game}"]
    name_arr = []
    players.each do |pl|
      name_arr << pl.name
    end
    #str = name_arr.join(",")
    # options exported to the network are managed from game_inprogress instance
    # game_in_pro is hols in connection
    game_option = @nal_srv.get_options_fornewmatch 
    
    str_cmd = JSON.generate([@name_core_game, name_arr, game_option])
    @player_conn.send_data( @player_conn.build_cmd(:onalg_new_match, str_cmd) )
    # notify also game in progress
    @game_inprog.onalg_new_match 
  end
  
  def onalg_new_giocata(carte_player)
    str = carte_player.join(",")
    @player_conn.send_data( @player_conn.build_cmd(:onalg_new_giocata, str) )
  end
  
  def onalg_newmano(player) 
    @log.debug "NAL_Srv_Algorithm new mano"
    @player_conn.send_data( @player_conn.build_cmd(:onalg_newmano, player.name) )
  end
  
  def onalg_have_to_play(player,command_decl_avail)
    #pack  this 2 fields into a yaml array, use YAML::load to decode it
    # if more than 20 commands are need to be sent, may be is better to compress it 
    str_cmd = JSON.generate([player.name, command_decl_avail])
    @player_conn.send_data( @player_conn.build_cmd(:onalg_have_to_play, str_cmd) ) 
  end
  
  def onalg_player_has_played(player, card)
    str = "#{player.name},#{card}"
    @player_conn.send_data( @player_conn.build_cmd(:onalg_player_has_played, str) ) 
  end
  
  def onalg_player_has_declared(player, name_decl, points)
    str = "#{player.name},#{name_decl},#{points}"
    @player_conn.send_data( @player_conn.build_cmd(:onalg_player_has_declared, str) )
  end
  
  def onalg_pesca_carta(carte_player) 
    str = carte_player.join(",")
    @player_conn.send_data( @player_conn.build_cmd(:onalg_pesca_carta, str) )
  end
  
  def onalg_player_pickcards(player, carte_player) 
    str_cmd = JSON.generate([player.name, carte_player]) 
    @player_conn.send_data( @player_conn.build_cmd(:onalg_player_pickcards, str_cmd) )
  end
  
  def onalg_manoend(player_best, carte_prese_mano, punti_presi)
    str_cmd = JSON.generate([player_best.name, carte_prese_mano, punti_presi ]) 
    @player_conn.send_data( @player_conn.build_cmd(:onalg_manoend, str_cmd) )
  end
  
  def onalg_giocataend(best_pl_points)
    str_cmd = JSON.generate(best_pl_points) 
    @player_conn.send_data( @player_conn.build_cmd(:onalg_giocataend, str_cmd) ) 
  end
  
  def onalg_game_end(best_pl_segni) 
    str_cmd = JSON.generate(best_pl_segni) 
    @player_conn.send_data( @player_conn.build_cmd(:onalg_game_end, str_cmd) )
    
    nal = @player_conn.game_in_pro.nal_server if @player_conn.game_in_pro
    if nal
      # save the played game into a file (CAUTION: this function is called for each player
      # but we need to do this stuff only at once) 
      nal.save_game(@ix_game)
      # save information about game into the db
      nal.save_score_indb()
    end
    @game_inprog.onalg_game_end 
  end
  
  def onalg_player_has_changed_brisc(player, card_briscola, card_on_hand) 
    str = "#{player.name},#{card_briscola},#{card_on_hand}"
    @player_conn.send_data( @player_conn.build_cmd(:onalg_player_has_changed_brisc, str) )
  end
  
  def onalg_player_has_getpoints(player,points)
    str = "#{player.name},#{points}"
    @player_conn.send_data( @player_conn.build_cmd(:onalg_player_has_getpoints, str) )
  end
  
  def onalg_player_cardsnot_allowed(player, cards)
   carte_str = cards.join(",")
   str = "#{player.name},#{carte_str}"
   @player_conn.send_data( @player_conn.build_cmd(:onalg_player_cardsnot_allowed, str) )
  end
  
  def onalg_player_has_taken(player, cards)
    carte_str = cards.join(",")
    str = "#{player.name},#{carte_str}"
    @player_conn.send_data( @player_conn.build_cmd(:onalg_player_has_taken, str) )
  end
  
  def onalg_new_mazziere(player)
    str = "#{player.name}"
    @player_conn.send_data( @player_conn.build_cmd(:onalg_new_mazziere, str) )
  end
  
  def onalg_gameinfo(info)
    str_cmd = JSON.generate(info)
    @player_conn.send_data( @player_conn.build_cmd(:onalg_gameinfo, str_cmd) )
  end
  
  
end #end class NAL_Srv_Algorithm

######################################### 
###            NAL_Srv_SpazzAlgo
#########################################

##
# Class to handle spazzino and similar algorithm callback
# We need to specify a different protocol interface for
# onalg_newmano and onalg_player_has_played
class NAL_Srv_SpazzAlgo < NAL_Srv_Algorithm
  
  def initialize(conn,  game_inprog)
    super(conn, game_inprog)
  end
  
  # override methods in the AlgBase interface
  
  # arrInfoTurn: array where the first item is the player on turn, followed
  # by cards on table
  def onalg_newmano(arrInfoTurn)
    @log.debug "NAL_Srv_SpazzAlgo new mano"
    str = "#{arrInfoTurn[0].name}," 
    str += arrInfoTurn[1..-1].join(",")
    @player_conn.send_data( @player_conn.build_cmd(:onalg_newmano, str) )
  end
  
  # card : [cardplayed, [cardtaken]]
  def onalg_player_has_played(player, card)
    str_cmd = JSON.generate([player.name, card])
    @player_conn.send_data( @player_conn.build_cmd(:onalg_player_has_played, str_cmd) ) 
  end
  
end

######################################### 
###            ServViewerGame
#########################################

class ServViewerGame < ViewerGameBase
  def initialize(conn)
    @player_conn = conn
  end
  
  def alg_changed(info)
    send_command(info, :alg_changed)
  end
  
  def current_state(info) 
    send_command(info, :current_state)
  end
  
  def send_command(info, m_symb)
    str_cmd = JSON.generate({:cmd => :serv_resp,
                        :resp_detail =>
                        { :method => m_symb, :info =>  info }
                        })
    @player_conn.send_data( @player_conn.build_cmd(:game_view,  str_cmd ))
  end
end


end #end module MyGameServer

#file: viewgame_list.rb

$:.unshift File.dirname(__FILE__)

require 'rubygems'

require 'log4r'
require 'pg_item'
require 'list_cup_common'
require 'network/prot_buildcmd'
require 'network/prot_parsmsg'
require 'json'

module MyGameServer

##
# Manage pending game request and join
class ViewGameList < ListCupCommon
  
  include ProtBuildCmd # for build_cmd
  
  def initialize(dir_log)
    super(dir_log)
    @subscribed_game_view_list = {}
  end
  
  def remove_connection( conn )
    @subscribed_game_view_list.delete(conn.user_name)
  end
 
  def game_view_start_view(conn, ix, gip)
    if gip
      str_cmd = {:cmd => :serv_resp,
                 :resp_detail => {:result => :ok_start_view}}
      conn.send_data(conn.build_cmd(:game_view,  str_cmd ))
      gip.start_viewer(conn)
    end
  end
  
  def get_num_inprogress_public(game_in_progress)
    count = 0
    game_in_progress.each do |k,game|
      count +=1 if !game.nal_server.is_privategame?
    end
    return count
  end
  
  ##
  # Player request game on going list using interface 2
  def view_games_req_list2(conn, game_in_progress)
    # add the connection to 
    @subscribed_game_view_list[conn.user_name] = conn
    # build a response command
    count  = 0
    # step slice, when we have reach this number we send the list 
    step = 5
    cmd_det = ""
    slice_nr = 0
    num_gameview = get_num_inprogress_public(game_in_progress)
    str_rec_coll = ""
    type_list =  :gameviewlist
    arr_gv = []
    # if the list is empty we send also the list
    if num_gameview == 0
      cmd_det = create_hash_forlist2(type_list, slice_nr, :last, arr_gv)
      # send an empty list
      conn.send_data(build_cmd(:list2, JSON.generate(cmd_det)))
      return
    end
    
    game_in_progress.each do |k,v|
      next if v.nal_server.is_privategame?
      gameview_hash = create_hash_forgameview_add(v)
      arr_gv << gameview_hash
      count += 1
      if count >= num_gameview
        # last item in the list, send it
        cmd_det = create_hash_forlist2(type_list, slice_nr, :last, arr_gv)
        conn.send_data(build_cmd(:list2, JSON.generate(cmd_det)))
      elsif(count % step)  == 0
        # reach the maximum block, send records in the slice
        cmd_det = create_hash_forlist2(type_list, slice_nr, :inlist, arr_gv)
        conn.send_data(build_cmd(:list2, JSON.generate(cmd_det)))
        
        arr_gv = []
        slice_nr += 1 
      end  
    end
  end
  
  def unsubscribe_user_game_view(user_name)
    @subscribed_game_view_list.delete(user_name)
  end
  
  def create_hash_forgameview_add(game_inpg)
    return          {:index => game_inpg.ix_game,
                     :players => game_inpg.nal_server.get_list_playersname,
                     :viewers => game_inpg.nal_server.get_list_viewersname,
                     :is_scoredgame => game_inpg.nal_server.is_scoredgame,
                     :game_name => game_inpg.nal_server.name_core_game,
                     }
  end
  
end#PendingGameList


end#end MyGameServer

if $0 == __FILE__
  require "test/test_common"
  
  include Log4r
  log = Log4r::Logger.new("serv_main")
  log.outputters << Outputter.stdout 
  viewgame = MyGameServer::ViewGameList.new
  conn = FakeUserConn.new
  conn.user_name = 'marta'
  viewgame.view_games_req_list2(conn, {})
end
#file test_core_server2.rb
# Test function for testing cup_serv_core.rb

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'test/unit'
require 'log4r'
require 'json'
require 'test_common'


PATH_TO_SERVER = File.expand_path(File.dirname(__FILE__) + '/..')
require File.join( PATH_TO_SERVER, 'cup_serv_core')

include Log4r

##
# Test suite for testing 
class Test_CupServerCore2 < Test::Unit::TestCase
  
  
  def setup
    @log = Log4r::Logger.new("serv_main")
    @server = MyGameServer::CuperativaServer.instance
    @server.reset_server
  end
  
  ######################################### TEST CASES ########################
=begin  
  ##
  # Test join game using standard join
  def test_pg_remove
    @log.outputters << Outputter.stdout
    # create 2 users
    myconn = FakeUserConn.new
    @server.accept_name?(myconn.user_name, myconn.user_passw, myconn)
    @server.pending_games_req_list(myconn)
    
    myconn2 = FakeUserConn.new
    myconn2.user_name = 'Mangiatonti'
    @server.accept_name?(myconn2.user_name, myconn2.user_passw, myconn2)
    @server.pending_games_req_list(myconn2)
    
    # create game
    pin = "3456"
    msg_details = "Spazzino,target_points=21;gioco_private=true;pin=#{pin}"
    @server.pending_game_create(myconn, msg_details)
    # now test remove pg game
    puts "remove pg game with error"
    # check the error on server (code 1)
    ix_game = 2
    @server.pending_game_removereq(myconn, ix_game.to_s)
    assert_match(/SRVERROR:1/, myconn.last_data_sent)
    # check removing ok
    puts "remove pg game OK"
    ix_game = 1
    @server.pending_game_removereq(myconn, ix_game.to_s)
    assert_match(/PGREMOVE:#{ix_game}/, myconn.last_data_sent)
    assert_match(/PGREMOVE:#{ix_game}/, myconn2.last_data_sent)
  end
  
  ##
  # test update_req
  def test_updatecheck
    @log.outputters << Outputter.stdout
    # create one user
    myconn = FakeUserConn.new
    @server.accept_name?(myconn.user_name, myconn.user_passw, myconn)
    
    # check update
    nomeprog = 'Cuperativa'
    arr_str =  "Ver 9.6.0 05102008".split(" ")
    ver_arr = arr_str[1].split(".")
    ver_arr.collect!{|x| x.to_i}
    ver_prog = ver_arr
    net_prot_ver = [4, 1 ]
    info_client = [nomeprog, ver_prog, net_prot_ver ]
    msg_details = JSON.generate(info_client)
    myconn.cmdh_update_req(msg_details)
    assert_match(/UPDATERESPTWO:--- \n:type: :nothing/, myconn.last_data_sent)
  end
  
  ##
  # test update_req with full update response
  def test_updatecheck_fullupdate
    @log.outputters << Outputter.stdout
    # create one user
    myconn = FakeUserConn.new
    @server.accept_name?(myconn.user_name, myconn.user_passw, myconn)
    
    # check update
    nomeprog = 'Cuperativa'
    client_ver_str = "Ver 0.5.4 05102008"
    arr_str =  client_ver_str.split(" ")
    ver_arr = arr_str[1].split(".")
    ver_arr.collect!{|x| x.to_i}
    ver_prog = ver_arr
    net_prot_ver = [4, 1 ]
    info_client = [nomeprog, ver_prog, net_prot_ver ]
    msg_details = JSON.generate(info_client)
    puts "Check server update with client: #{client_ver_str}"
    myconn.cmdh_update_req(msg_details)
    assert_match(/UPDATERESPTWO:--- \n:server: http/, myconn.last_data_sent)
  end
  
  ##
  # Test join game
  def test_join_briscolaprivate_game_nopin
    @log.outputters << Outputter.stdout
    # create 2 users
    myconn = FakeUserConn.new
    @server.accept_name?(myconn.user_name, myconn.user_passw, myconn)
    @server.pending_games_req_list(myconn)
    
    myconn2 = FakeUserConn.new
    myconn2.user_name = 'Mangiatonti'
    @server.accept_name?(myconn2.user_name, myconn2.user_passw, myconn2)
    @server.pending_games_req_list(myconn2)
    
    # create game
    pin = "3456"
    msg_details = "Briscola,target_points_segno=61;num_segni_match=2;gioco_private=true;pin=#{pin}"
    #msg_details = "Mariazza,target_points_segno=61;num_segni_match=2;gioco_private=true;pin=#{pin}"
    #msg_details = "Spazzino,target_points=21;gioco_private=true;pin=#{pin}"
    @server.pending_game_create(myconn, msg_details)
    ix_vor_last = myconn.data_sent.size - 2
    #p myconn.data_sent[ix_vor_last]
    assert_match(/PGADD:1,Tontouser,Briscola,<vittoria ai 61,segni 2 ,gioco privato>/, myconn.data_sent[ix_vor_last] )
    # now test join using another user
    puts "Try to join the game..."
    ix_game = 1
    #pin = '113456'
    @server.join_req_private(myconn2, ix_game.to_s, pin)
    assert_match(/PGJOINTENDER/, myconn.last_data_sent)
    # now the creator should confirm the game
    msg_details = "#{myconn2.user_name},#{ix_game}"
    myconn.cmdh_pg_join_ok(msg_details)
    assert_match(/ONALGHAVETOPLAY/, myconn2.last_data_sent)
  
  end
=end
  def test_pg_remove
    @log.outputters << Outputter.stdout
    # create 2 users
    myconn = FakeUserConn.new
    @server.accept_name?(myconn.user_name, myconn.user_passw, myconn)
    @server.pending_games_req_list(myconn)
    
    myconn2 = FakeUserConn.new
    myconn2.user_name = 'Igor1'
    @server.accept_name?(myconn2.user_name, myconn2.user_passw, myconn2)
    @server.pending_games_req_list(myconn2)
    #create 2 games
    msg_details = "Briscola,target_points_segno=61;num_segni_match=2;"
    @server.pending_game_create(myconn, msg_details)
    @server.pending_game_create(myconn2, msg_details)
    # delete game
    @server.pending_game_removereq(myconn, 2 )
    assert_match(/SRVERROR:2/, myconn.last_data_sent)
  end
  
end #Test_CupServerCore2

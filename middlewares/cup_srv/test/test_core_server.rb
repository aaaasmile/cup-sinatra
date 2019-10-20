#file test_core_server.rb
# Test function for testing cup_serv_core.rb

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'test/unit'
require 'log4r'
require 'yaml'
require 'test_common'


PATH_TO_SERVER = File.expand_path(File.dirname(__FILE__) + '/..')
require File.join( PATH_TO_SERVER, 'cup_serv_core')

include Log4r

##
# Test suite for testing 
class Test_CupServerCore < Test::Unit::TestCase
  
  
  def setup
    @log = Log4r::Logger.new("serv_main")
    @server = MyGameServer::CuperativaServer.instance
    @server.reset_server
  end
  
  ######################################### TEST CASES ########################
  
  ##
  # Test pending game create with private option
  def test_pending_game_create
    # set the custom logger
    io_fake = FakeIO.new(1,'w')
    IOOutputter.new('serv_main', io_fake)
    Log4r::Logger['serv_main'].add 'serv_main'
    @log.outputters << Outputter.stdout
    # pending game create
    myconn = FakeUserConn.new
    @server.pending_games_req_list(myconn)
    msg_det = 'Spazzino,target_points=21;gioco_private=true'
    @server.pending_game_create(myconn, msg_det)
    ix_vor_last = myconn.data_sent.size - 2
    assert_match(/PGADD:1,Tontouser,Spazzino,<vittoria ai 21>/, myconn.data_sent[ix_vor_last] )
    assert_match(/INFO:Richiesta di partita creata con indice 1, vista da 0 utenti./, myconn.last_data_sent)
  end
  
  ##
  # Test join game
  def test_join_game
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
    msg_details = 'Spazzino,target_points=21;gioco_private=false'
    @server.pending_game_create(myconn, msg_details)
    # now test join using another user
    puts "Try to join the game..."
    ix_game = 1
    msg_details = ix_game.to_s
    @server.join_req_part1(myconn2, msg_details)
    # now the creator should confirm the game
    msg_details = "#{myconn2.user_name},#{ix_game}"
    myconn.cmdh_pg_join_ok(msg_details)
    assert_match(/ONALGHAVETOPLAY/, myconn2.last_data_sent)
  end
  
  ##
  # Test join game
  def test_join_private_game_nopin
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
    msg_details = 'Spazzino,target_points=21;gioco_private=true'
    @server.pending_game_create(myconn, msg_details)
    ix_vor_last = myconn.data_sent.size - 2
    assert_match(/PGADD:1,Tontouser,Spazzino,<vittoria ai 21>/, myconn.data_sent[ix_vor_last] )
    # now test join using another user
    puts "Try to join the game..."
    ix_game = 1
    msg_details = ix_game.to_s
    @server.join_req_part1(myconn2, msg_details)
    assert_match(/PGJOINTENDER/, myconn.last_data_sent)
    # now the creator should confirm the game
    #msg_details = "#{myconn2.user_name},#{ix_game}"
    #myconn.cmdh_pg_join_ok(msg_details)
  end
  
  
  
  ##
  # Test join game
  def test_join_private_pin
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
  
  ##
  # Test join game using standard join
  def test_join_private_pin_withstdjoin
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
    #msg_details = "Spazzino,target_points=21;gioco_private=true"
    @server.pending_game_create(myconn, msg_details)
    # now test join using another user
    puts "Try to join the game with standard join, expect reject"
    ix_game = 1
    @server.join_req_part1(myconn2, ix_game.to_s)
    assert_match(/PGJOINREJECT/, myconn2.last_data_sent)
  end
  
  ##
  # Test nal ineteger option setter
  def test_setoptions_interger
    # spazzino target points
    nal = MyGameServer::NALServerCoreGameSpazzino.new(1)
    assert_equal(false, nal.core_game.game_opt[:gioco_private])
    nal.set_option_integer("target_points","22")
    assert_equal(22, nal.core_game.game_opt[:target_points])
    # all nal servers
    PendingGameList.games_available.each do |k,v|
      nal = eval("MyGameServer::#{v[:class_name]}").new(1)
      nal.set_option_integer("gioco_private","true")
      assert_equal(true, nal.core_game.game_opt[:gioco_private])
      nal.set_option_integer("gioco_private","false")
      assert_equal(false, nal.core_game.game_opt[:gioco_private])
    end
  end
  
end

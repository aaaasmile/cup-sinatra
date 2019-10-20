# file: game_in_prog_item.rb
# File used to store information about game in progress

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'network/prot_buildcmd'
require 'restart_to_another_game'

module MyGameServer

	include Log4r
    
  ##
  # Class to handle a game in progress item
  # A game in progess could be considerated as a game table
  class GameInProgressItem
    attr_accessor :nal_server,:players
    attr_reader :ix_game
    
    ##
    # pl_list: array of user names
    def initialize(pl_list, nal_server, ix)
      # Interface adapter between server socket and core game  
      @nal_server = nal_server
      # List of all players that have joined the game, array of user names
      @players = pl_list
      # game in progress index  as string
      @ix_game = ix
      reset_restart_state
      # hash with username name as key and connection as value
      @conn_players = {}
      #hash players username that leave the game. key is user name, value {:time, :freq, :reason}
      @disconnected_players = {}
      # logger
      @log = Log4r::Logger["coregame_log"]
    end
    
    def set_connection(user_name, conn)
      @log.debug "Set connection for #{user_name}"
      @conn_players[user_name] = conn
    end
    
    def reset_restart_state
      @restart_another = nil
    end
    
    ### START connection request
    
    def create_restart_another_req(conn, info_detail)
      if @restart_another
        @restart_another.create_req(conn, info_detail)
			else
				@log.warn "Ignore request because there is already another one"
      end
    end
    
    def join_restart_another_req(conn, info_detail)
      if @restart_another
        @restart_another.join_req(conn)
        if @restart_another.is_game_ready_to_restart? 
          do_restart_another_game(@restart_another.get_num_of_join(:ok),
              @restart_another.get_game_info )
        end
      end
    end
    
    def decline_restart_another_req(conn, info_detail)
      if @restart_another
        @restart_another.decline_req(conn)
      end
    end
    
    def restart_this_game_req(user_name, g_ix)
      if @restart_another != nil
        @restart_another.restart_this_game_req(user_name, g_ix)
        if @restart_another.is_game_ready_to_restart?
          @log.debug "ready to restart this game"
          do_restart_this_game(@restart_another.get_num_of_join(:ok))
        else
          @log.debug "Not yet ready to restart this game (ok num: #{@restart_another.get_num_of_join(:ok)})"
        end
      end
    end
    
    ### END connection request
    
    ##
    # Player leave this game in progress. Function returns the number of players that are
    # on the game in progress
    # reason: e.g. :disconnect
    def player_disconnect(user_name, reason)
      player_leaved(user_name, reason)
      if @disconnected_players[user_name]
        @disconnected_players[user_name][:freq] += 1
      else
        @disconnected_players[user_name] = {:freq => 1}
      end 
      @disconnected_players[user_name][:time] = Time.now
      @disconnected_players[user_name][:reason] = reason
      @disconnected_players[user_name][:status] = :disconnected
      
      return @players.size 
    end
    
    def player_leaved(user_name, reason)
      @nal_server.save_game_state_details(user_name, @ix_game)
      #@nal_server.resign_game(user_name, {:medium => :network, :detail => :player_leaved})
      #@nal_server.remove_player(user_name, reason)
      @players.delete(user_name)
      # on disconnect no chance to restart a game
      reset_restart_state # TODO
    end
    
    def player_abandon(user_name)
      @nal_server.resign_game(user_name, {:medium => :network, :detail => :abandon})
    end
    
    def do_restart_this_game( num_of_ok)
      #p num_of_ok
      if num_of_ok == @nal_server.get_numofplayer_tostart
        @log.info("Ready to restart this game #{@ix_game}")
        @nal_server.restart_new_game
      else
        @log.warn "Restart rejected because confirmed is smaller (#{num_of_ok}) then required players (#{@nal_server.get_numofplayer_tostart})"
      end
    end
    
    def do_restart_another_game(num_of_ok, game_info)
      @log.debug "Prepare for restart to another game"
      dir_log = @nal_server.dir_log
      game_name = info[:game]
      class_game = PendingGameList.get_game_available_value(game_name)
      nal_server_game = eval(class_game[:class_name]).new(@ix_game, dir_log)
      nal_server_game.set_option_info(info)
      nal_server_game.check_option_range
      
      players_nal = []
      @players.each do |user_name|
        conn = @conn_players[user_name]
        alg = eval(nal_server_game.nal_algorithm_name).new(conn, self)
        alg.name_core_game = nal_server_game.name_core_game
        players_nal << { :algorithm => alg, :user_name => user_name   }
      end
      
      @nal_server = nal_server_game
      if @restart_another != nil
        @log.info "Restart to another game #{game_name}"
        nal_server.start_new_game(players_nal)
      end
    end
    
    def do_core_process
      @nal_server.do_core_process if @nal_server
    end
    
    def start_viewer(conn)
      @nal_server.start_viewer(conn) if @nal_server
    end
    
    def connection_removed(conn)
      @nal_server.stop_viewer(conn) if @nal_server
    end
    
    ## Nal server notifications
    
    ##
    # Algorithm start a new match notification
    def onalg_new_match
      # reset the status about restart
      reset_restart_state
    end
    
    def  onalg_game_end
      @restart_another = RestartToAnotherGame.new(@conn_players)
    end
    
    def is_player_here?(user_name)
      ix = @players.index(user_name)
      return true if ix
      return false
    end
    
    def is_player_disconnectedhere?(user_name)
      if @disconnected_players.has_key?(user_name) 
        info = @disconnected_players[user_name]
        if info[:status] == :disconnected
          return true
        end
      end
      return false
    end
    
    ##
    # Player reconnect the game
    def player_reconnect(conn)
      user_name = conn.user_name
      info = @disconnected_players[user_name]
      info[:status] = :reconnected
      @conn_players[user_name] = conn
    end
    
  end #end GameInProgress
  
end#end module
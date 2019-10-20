# file: nal_srv_base.rb
# Base file for server nal

$:.unshift File.dirname(__FILE__) + '/..'

require 'rubygems'
require 'database/sendemail_errors'
require 'fileutils'
require 'log4r'



module MyGameServer

	# NalServer è una classe usata pe intercettare i comandi del client
	# che vengono mandati al server, precisamente al core_game C ----> S 

	##
	# Class used to implement basic common funtions
	class NalServerCoreBase
		attr_reader :name_core_game, :dir_log, :state_game, :info_hash
		attr_reader :core_game #initialized into inherited class
		attr_reader :nal_algorithm_name, :ix_game, :name_core_game, :is_scoredgame
		attr_accessor :db_connector
  
		def initialize(game_name, ix, dir_log)
			@dir_log = dir_log
			@ix_game = ix
			# set own  logger for each nal server
			@log_fname = Time.now.strftime("%H_%M")
			curr_day = Time.now.strftime("%Y_%m_%d")
			base_dir_log = File.join(dir_log, curr_day)
			@options_for_core_game = {}
			@info_hash  = {}
    
			@core_game = nil #initialized into inherited class
			@name_core_game = nil #initialized into inherited class
    
			@num_of_players = 2 # TODO use the size of @core_game num of players
			@log = Log4r::Logger["coregame_log"] 
			
			@game_count = 0
			@initial_game_name = game_name
			@path_to_logs = base_dir_log
			@nal_corelog_filename = @path_to_logs + "/#{build_game_name()}.log"
    
			# used to find PlayerOnGame using server user_name as key
			# this hash is initialized when a new game is started
			@players_for_core = {}
			# players that sent gui_new_segno
			@player_cfm_newsegno = {}
			# players given to the core
			@core_players = []
			# game state: game_not_started, game_started, game_saved, game_saved_indb
			@state_game =  :game_not_started
			#default nal algorithm class name
			@nal_algorithm_name = 'NAL_Srv_Algorithm'
			# private game flag
			@is_privategame = false
			# scored_game valid game
			@is_scoredgame = true
			# players hash (loginname => user_id) for update db
			@players_indb = {}
			# used to access to the database
			@db_connector = nil
			# store options for core before create it
			@options_for_core_game = {}
			 # used to find Connection as viewer using server user_name as key
			@viewers_list = {}
		end

		def set_pgindex(pg_index)
			@log.debug("Changing the index to #{pg_index}")
			@ix_game = pg_index
		end
  
		##
		# provides the list of players name
		def get_list_playersname
			res = []
			@players_for_core.each do |k,v|
				res << k
			end
			return res
		end
  
		##
		# provides the list of players name
		def get_list_viewersname
			res = []
			@viewers_list.each do |k,v|
				res << k
			end
			return res
		end
  
		def create_match_file_log
			#p [:corelog_file_name, @nal_corelog_filename]
			#if !File.exist?(@nal_corelog_filename) or
				#Log4r::Logger['coregame_log'].outputters.size == 0
				# log the core only if the file don't already exist
				#FileOutputter.new('coregame_log', :filename=> @nal_corelog_filename)
				#if Log4r::Logger['coregame_log']
				#	Log4r::Logger['coregame_log'].add 'coregame_log'
				#end
			#end
		end
  
		##
		# Log info for this table
		def log_table_comm(str)
			@log.warn(str)
		end
  
		def is_privategame?
			return @is_privategame
		end
  
		def check_for_nullscore(score)
			if score <= 0
				score = 1000
			end
			return score
		end

		# Save user id
		# username: username as login, case sensitive
		# db_user: record from table User in db
		def set_userdb_info(username, db_user)
			# db_user.login is case insesitive, don't use it
			@players_indb[username] = db_user.id
		end

		def get_userdb_info(username)
			return @players_indb[username]
		end
  
		##
		# Set options using an info hash
		def set_option_info(info)
			@is_privategame = info["prive"]["val"]
			@is_scoredgame = info["class"]
			info["opt_game"].each do |k,v|
				@options_for_core_game [k] = v["val"]
			end
			@info_hash = info
		end
  
		##
		# Check if the game can start. Provides true if the game can start, false otherwise.
		# pg_item: pg item
		def game_canstart?(pg_item)
			#if pg_item.get_num_of_players == @core_game.game_opt[:num_of_players]
			if pg_item.get_num_of_players == @num_of_players
				# enought players to start
				return true
			end
			return false
		end
 
		##
		# A player give up
		# user_name: resign player
		# reason: :abandon or :disconnection
		def resign_game(user_name, reason)
			@log.debug "resign game by #{user_name}, reason #{reason}"
			if @state_game == :game_started
				player = @players_for_core[user_name] 
				if player
					@core_game.alg_player_resign(player, reason )
					#@core_game.process_next_gevent
				end
			else
				@log.debug "Ignore resign because game is not started, but #{@state_game}"
			end
		end
  
		##
		# Start a new core network game
		# players_net: array of hash with user_name and NAL_Srv_algorithm
		def start_new_game(players_net)
			create_match_file_log
			create_core_game
			@log.debug "nal_srv: start a new game"
			@state_game = :game_started
			# use @ix_game to save in db
			unless @db_connector.nil?
				CupDbDataModel::CupPgItem.update_status_pgitem(@ix_game, @state_game.to_s, @db_connector.active_pg_conn)
				@log.debug("Updated pgitem in db with id #{@ix_game}")
      end    

			@core_players = []
			pos = 0
			@players_for_core = {}
			@viewers_list = {}
			players_net.each do |pl_hash_info|
				alg = pl_hash_info[:algorithm]
				username = pl_hash_info[:user_name]
				pl_core  = PlayerOnGame.new(username, alg, :human_remote, pos)
				@players_for_core[username] = pl_core
				@core_players << pl_core
				pos += 1
			end
			@core_game.gui_new_match(@core_players)
			#@core_game.process_next_gevent
		end
  
		##
		# The connection is now a game viewer
		def start_viewer(conn)
			# TODO: qualcosa non quadra qui...
			#@viewers_list[conn.user_name] = conn
			#viewer = ServViewerGame.new(conn)
			#@core_game.add_viewer(conn.user_name, viewer) if @core_game
		end
  
		def stop_viewer(conn)
			# TODO: qualcosa non quadra qui..., ricevo sempre email
			#@viewers_list.delete(conn.user_name)
			#@core_game.remove_viewer(conn.user_name) if @core_game
		end
  
		def build_game_name
			return "#{@initial_game_name}_#{@log_fname}_#{@ix_game}"
		end
  
		##
		# Save the last played game into a file
		def save_game(ix_game)
			if @state_game ==  :game_started # TODO salva nel db invece del file
				@game_count += 1
				fname = @path_to_logs + "/#{build_game_name}-savedmatch.yaml"
				@core_game.save_curr_game(fname)
				# avoid to save the game more that once
				@state_game = :game_saved 
			else
				@log.debug "Ignore save game because state is #{@state_game}"
			end
		end

		def save_game_state_details(username, ix_game)
			# TODO salva nel db, campo status details
		end
  
		##
		# Save the score for each player into the db
		def save_score_indb()
			@log.debug "Save game in db"
			if @state_game == :game_saved
				@state_game = :game_saved_indb
				unless @is_scoredgame
					@log.info "Relax game don't need to update data in db"
					return
				end
				if @core_game.is_matchsuitable_forscore?
					begin
						@log.debug "going to update the db..."
						update_ranking
					rescue => detail
						str_err = "Impossible to save update in db: #{$!}"
						str_err += detail.backtrace.join("\n")
						error_msg_macthserver(str_err) 
					end
				else
					@log.info "Game has not enought information to update players score"
				end
			else
				@log.debug "Save game in db: ignore, because already done"
			end
		end
  
		##
		# Log an error message on match
		def error_msg_macthserver(msg)
			@log.outputters << Outputter.stdout
			@log.error(msg)
			@log.outputters.delete(Outputter.stdout)
			# send also an email for this kind of errors
			sender = EmailErrorSender.new(@log)
			sender.send_email("Match server error:\n" + ("#{msg}\n"))
		end
  
		def raise_err_usernotfound(user_name)
			str_err =  "User id not found for username #{user_name}\n"
			str_err += debug_players_indb
			error_msg_macthserver(str_err)
		end
  
		def debug_players_indb
			strres =  "@players_indb detail : \n"
			@players_indb.each do |k,v|
				strres.concat( "#{k} id = #{v}\n" )
			end
			return strres
		end
  
		###################### abstract functions that have to be overriden in the child ##############
  
		def update_ranking
			@log.error("Plase implement update_ranking on nalserver ")
		end
  
		##
		# Check custom options if they are on range. If not set it to default.
		def check_option_range
			@log.error("Plase implement check_option_range on nalserver ")
		end
  
		##
		# Provides options exported on the network
		def get_options_fornewmatch
			@log.error("Plase implement get_options_fornewmatch on nalserver ")
		end
  
		##
		# Provides the number of players required to start a new match
		def get_numofplayer_tostart
			return @num_of_players
		end
  
		##
		# Restart a new game. This is different from start_new_game
		# because players are already defined
		def restart_new_game
			# create a new core instance
			@state_game = :game_started
			@log.info("Restart a new match on #{@core_game_name}")
			create_core_game
			@core_game.gui_new_match(@core_players)
		end
  
		def create_core_game
			@log.debug "nal_srv: create core game #{@core_game_name}"
			@core_game = eval(@core_game_name).new
			@core_game.game_opt[:gioco_private] = false
    
			@options_for_core_game.each do |k,v|
				#p v
				#p k
				#p @core_game.game_opt
				#@core_game.game_opt[k] = v[:val]
				@core_game.game_opt[k] = v
			end
		end
  
		def do_core_process 
			@core_game.process_only_one_gevent if @core_game
		end
  
		######## Methods called from remote algorithm
  
		##
		# Client change the briscola
		# user_name: string for login user name
		def alg_player_change_briscola( user_name, card_briscola, card_on_hand )
			player = check_user_name(user_name)
			@core_game.alg_player_change_briscola(player, card_briscola, card_on_hand )
			#@core_game.process_next_gevent
		end
  
		##
		#
		def alg_player_declare( user_name, name_decl )
			player = check_user_name(user_name) 
			@core_game.alg_player_declare(player, name_decl )
			#@core_game.process_next_gevent
		end
  
		##
		#
		def alg_player_cardplayed(user_name, card)
			player = check_user_name(user_name)
			##test delay 
			# sleep is quick and dirty test for delay between client call of
			# alg_player_cardplayed and on_alg_has_played notification
			#sleep 4
			#end test delay 
			@core_game.alg_player_cardplayed(player, card )
			#@core_game.process_next_gevent
		end
  
		##
		#
		def alg_player_cardplayed_arr(user_name, card_arr)
			player = check_user_name(user_name)
			@core_game.alg_player_cardplayed_arr(player, card_arr )
			#@core_game.process_next_gevent
		end

		## methods called from remote gui
  
		##
		# The remote client trigger a new segno. This mean that the game can continue
		# What condition for continue? Waiting all clients that they are called
		# gui_new_segno on the server? 
		def gui_new_segno( user_name)
			@player_cfm_newsegno[user_name] = :ok
			num_of_ok = count_nr_of_ok
			if num_of_ok >= @players_for_core.size
				@core_game.gui_new_segno
				@player_cfm_newsegno = {}
			else
				@log.info("gui_new_segno players confirmed: #{num_of_ok}/#{@players_for_core.size}")
			end
			#@core_game.process_next_gevent
		end
  
	private
		##
		# Count the number of oks
		def count_nr_of_ok
			count = 0
			@player_cfm_newsegno.each_value do |v| 
				count += 1 if v == :ok
			end
			return count
		end

		def check_user_name(user_name)
			player = @players_for_core[user_name]
			if player == nil
				p [:core_players, @players_for_core]
				raise("Invalid user name #{user_name}")
			end
			return player
		end
  
  
	end#end NalServerCoreBase



end# end module MyGameServer
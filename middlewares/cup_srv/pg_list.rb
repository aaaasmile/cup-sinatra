#file: pg_list.rb

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'log4r'
require 'pg_item'
require 'list_cup_common'
require 'network/prot_buildcmd'
require 'network/prot_parsmsg'
require 'json'

# supported games
require 'nal_games/nal_srv_mariazza'
require 'nal_games/nal_srv_briscola'
require 'nal_games/nal_srv_spazzino'
require 'nal_games/nal_srv_scopetta'
require 'nal_games/nal_srv_tombolon'
require 'nal_games/nal_srv_briscolone'
require 'nal_games/nal_srv_tressette'
require 'nal_games/nal_srv_tressettein4'

include Log4r

module MyGameServer
  
  ##
  # Manage pending game request and join
  class PendingGameList < ListCupCommon
    
    # list of available games
    @@games_available = {
      'Mariazza' => {:class_name => 'NALServerCoreGameMariazza'},
      'Briscola' => {:class_name => 'NALServerCoreGameBriscola'},
      'Spazzino' => {:class_name => 'NALServerCoreGameSpazzino'},
      'Tombolon' => {:class_name => 'NALServerCoreGameTombolon'},
      'Scopetta' => {:class_name => 'NALServerCoreGameScopetta'},
      'Briscolone' => {:class_name => 'NALServerCoreGameBriscolone'},
      'Tressette' => {:class_name => 'NALServerCoreGameTressette'},
      'Tressettein4' => {:class_name => 'NALServerCoreGameTressettein4'},
    }
    
    include ProtBuildCmd # for build_cmd
    include ParserCmdDef # for error
    
    def initialize(log_dir)
      super(log_dir)

      # list of subscribed pending game info. Use user_name to identify a user
      @subscribed_pg_user_list = {}
      @pg_index_arr = []
      # pending game list. Hash with key index and value instance of PgItem
      @pg_list  = {}
      init_pg_array_index 
    end
    
    def get_game_available
      return @@games_available
    end
    
    def self.get_game_available_value(game_key_name) 
      return @@games_available[game_key_name]
    end
    
    def self.is_game_valid?(game_key_name)
      return @@games_available.has_key?(game_key_name) ? true : false
    end
    
    def remove_connection( conn )
      @subscribed_pg_user_list.delete(conn.user_name)
      # pending game entries
      # @pg_list.each do |k,v|
      #   v.disconnect_user(conn)
      #   if !v.is_conn_creator_available?
      #     pg_list_remove_index_reuse(k)
      #   end
      # end
    end

    def get_num_items
      return @pg_list.keys.size
    end 
    
    def pending_game_removereq(conn, pg_ix)
      if pg_ix.class != String
        @log.error("pg_ix expected as string, but it is #{pg_ix.class}")
        return
      end
      #p @pg_list
      is_admin = false
      unless @db_connector.nil?
        is_admin = CupDbDataModel::CupUser.is_admin(conn.user_id, @db_connector.active_pg_conn)
      end  
      if pg_ix == "-1"
        @log.debug "removing all pending requests for the user #{conn.user_name} - admin? = #{is_admin}"
        @pg_list.each do |ix,pgitem|
          if pgitem.get_creator_name == conn.user_name || is_admin
            pg_list_remove_index_reuse(ix)
          end
        end
        unless @db_connector.nil?
          begin
            if is_admin
              CupDbDataModel::CupPgItem.delete_all_pgitems(@db_connector.active_pg_conn)
            else
              CupDbDataModel::CupPgItem.delete_init_pgitems(conn.user_id, @db_connector.active_pg_conn)
            end
            @log.debug("Deleted in db all pending games for user #{conn.user_name}")
          rescue => detail
            @log.error("Unable to delete pgitem from db: #{$!}\n")
            msg = build_cmd(:srv_error, srv_error_code(:pg_remov_req_fail3))
            conn.send_data msg
            return nil
          end
        end
        return
      end

      pg_item = @pg_list[pg_ix]
      unless pg_item
        @log.debug "Rejected removed game ix #{pg_ix} not found" 
        msg = build_cmd(:srv_error, srv_error_code(:pg_remov_req_fail))
        conn.send_data msg
        return 
      end

      if conn.user_name == pg_item.get_creator_name
        # connection can remove the pg game
        @log.debug "Removed game ix#{pg_ix}"  
        pg_list_remove_index_reuse(pg_ix)
        unless @db_connector.nil?
          begin
            CupDbDataModel::CupPgItem.delete_pgitem_on_id(pg_ix, @db_connector.active_pg_conn)
            @log.debug("Deleted in db the pending game ix #{pg_ix}")
          rescue => detail
            @log.error("Unable to delete pgitem from db: #{$!}\n")
            msg = build_cmd(:srv_error, srv_error_code(:pg_remov_req_fail3))
            conn.send_data msg
            return nil
          end
        end
      else
        @log.debug "Not allowed to remove game ix#{pg_ix} because the owner is #{pg_item.get_creator_name} and you are #{conn.user_name}" 
        msg = build_cmd(:srv_error, srv_error_code(:pg_remov_req_fail2))
        conn.send_data msg
        return
      end
    end
  
    ##
    # Initialize pending game index array
    def init_pg_array_index
      @pg_index_arr = []
      (1..999).each {|ix| @pg_index_arr << ix.to_s}
      @pg_index_arr.reverse!
    end
  
    ##
    # Provides the next pending game index as string
    def get_pg_index
      @log.debug("get_pg_index: provides index: #{@pg_index_arr.last}")
      if @pg_index_arr.size == 0 
        init_pg_array_index
      end
      return @pg_index_arr.pop
    end
    ##
    # Delete a pg_item index and inform all user about a removed pending game entry
    # pg_index: pending game index to be removed
    def pg_list_remove_index_reuse(pg_index)
      reuse_pg_index(pg_index)
      pg_list_remove_index(pg_index)
    end
  
    ##
    # Remove all create pending game from player_list
    # player_list: array of user name
    def pg_list_remove_playerlist(player_list)
      player_list.each do |user_name|
        @pg_list.each do |curr_play_ix, pg_item|
          if user_name == pg_item.get_creator_name
            @log.debug("remove pg_game from :#{user_name} with ix #{curr_play_ix}")
            pg_list_remove_index_reuse(curr_play_ix)
          end
        end
      end
    end
  
    ##
    # Reuse a free index
    def reuse_pg_index(ix)
      @log.debug("reuse_pg_index: reuse index#{ix}")
      # we are using pop for getting, that mean we should to push on front the
      # last used value
      @pg_index_arr.insert(0,ix)
    end
  
    ##
    # Add pg item to list if it is valid. If the item was added to the list
    # then return the index, otherwise nil.
    # pg: istance of PgItem
    # ix: predifined ix. with "-1" use a new one. ix is a string
    def add_pg_item_tolist(pg, ix)
      index = nil
      if pg.is_valid?
        if ix == -1
          index = get_pg_index
        else
          index = ix
        end
        if index && (index.class == String)
          @pg_list[index] = pg
        else
          index = nil
        end
      end
      return index
    end
  
    ##
    # Provides the hash to be sent to the client with the pending game information
    def create_hash_forpgadd2(pg_index, pgi)
      return          {:index => pg_index,
        :user => pgi.get_creator_name,
        :user_type => pgi.get_creatorusertype,
        :user_score => pgi.creator_score,
        :game => pgi.game,
        :prive => pgi.is_private?,
        :class => pgi.is_scored_game?,
        :opt_game => pgi.options,
        :players => pgi.get_players_username_list }
    end
  
    ##
    # Player request pending game list using interface 2
    def pending_games_req_list2(conn)
      subscribe_user_pglist(conn)
      count  = 0
      # step slice, when we have reach this number we send the list 
      step = 5
      cmd_det = ""
      slice_nr = 0
      num_pg = @pg_list.size
      str_rec_coll = ""
      type_list =  :pgamelist
      arr_pgs = []
      # if the list is empty we send also the list
      if @pg_list.size == 0
        cmd_det = create_hash_forlist2(type_list, slice_nr, :last, arr_pgs)
        # send an empty list
        conn.send_data(build_cmd(:list2, JSON.generate(cmd_det)))
        return
      end
    
      @pg_list.each do |k,v|
        pg_hash = create_hash_forpgadd2(k, v)
        arr_pgs << pg_hash
        count += 1
        if count >= num_pg
          # last item in the list, send it
          cmd_det = create_hash_forlist2(type_list, slice_nr, :last, arr_pgs)
          conn.send_data(build_cmd(:list2, JSON.generate(cmd_det)))
        elsif(count % step)  == 0
          # reach the maximum block, send records in the slice
          cmd_det = create_hash_forlist2(type_list, slice_nr, :inlist, arr_pgs)
          conn.send_data(build_cmd(:list2, JSON.generate(cmd_det)))
        
          arr_pgs = []
          slice_nr += 1 
        end  
      end
    end
  
    ##
    # Inform all user about a new pending game entry
    # pg_index: pending game index
    # pgi: pending game item
    def inform_all_about_new_pg2(pg_index, pgi)
      det = create_hash_forpgadd2(pg_index, pgi)
      typelist = :pgamelist
      info = create_hash_forlist2addremove(typelist, det)
      info_yaml = JSON.generate(info)
      msg = build_cmd(:list2_add, info_yaml)
      @subscribed_pg_user_list.values.each{|conn| conn.send_data msg}
    end
  
    ##
    # Remove pg index from list
    def pg_list_remove_index(pg_index)
      @pg_list.delete(pg_index)
      info = {}
      typelist = :pgamelist
      det = { :index => pg_index.to_i}
      info = create_hash_forlist2addremove(typelist, det)
      info_yaml = JSON.generate(info)
      msg = build_cmd(:list2_remove, info_yaml)
      @subscribed_pg_user_list.values.each{|conn| conn.send_data(msg)}
    end
  
    ##
    # Unsubscribe username  from pending game list observer
    def unsubscribe_user_pglist(user_name)
      @subscribed_pg_user_list.delete(user_name)
    end
  
    def subscribe_user_pglist(conn)
      @subscribed_pg_user_list[conn.user_name] = conn
    end
  
    ##
    # Check if the user has already created a similar pg game, 
    # in this case return true, otherwise false. 
    def check_if_pg_ispending(user_name, game_name)
      @pg_list.values.each do |pg_item|
        if pg_item.get_creator_name == user_name and pg_item.game == game_name
          #user has already an entry similar
          return true
        end
      end
      return false
    end
  
    def check_if_user_is_pgitem_owner(user_name)
      @pg_list.values.each do |pg_item|
        if pg_item.get_creator_name == user_name
          return true
        end
      end
      return false
    end
  
    ##
    # Create a new pending game
    # conn: user connection, could be null when creating from db
    # info: something like:
    # '{"game"=>"Briscola", "prive"=>{"val"=>false, "pin"=>""}, "class"=>false, "opt_game"=>{"target_points_segno"=>{"type"=>"textbox", "name"=>"Punti vittoria segno", "val"=>61}, "num_segni_match"=>{"type"=>"textbox", "name"=>"Segni in una partita", "val"=>2}}}'
    # pg_index: if -1, get it from a db operation INSERT, otherwise use it
    def pending_game_create2(conn, info, num_clients, username, user_id, pg_index)
      @log.debug "Create pg item, owner #{username}, game #{info['game']}"
      
      game_name = info["game"]
      if game_name == nil
        @log.warn "Malformed message, game name is null. Ignore it";
        return nil
      end
      user_name = username
      # check if the game is supported
      class_game = @@games_available[game_name]
      unless class_game
        conn.send_data(build_cmd(:pg_create_reject, "pg_ceate gioco #{game_name} non supportato")) if conn
        return nil
      end
      # check if the user has already a pending game with this name
      if check_if_pg_ispending(user_name, game_name)
        conn.send_data(build_cmd(:pg_create_reject, 
          "Esiste gia' un gioco creato del tipo #{game_name} dall'utente #{user_name}")) if conn
        return nil
      end
    
      # create nal_server for this game (core and game state handling)
      nal_server = eval(class_game[:class_name]).new(pg_index, @dir_log)
      
      # Rankings
      creator_score = 0
      creator_gender = ''
      unless @db_connector.nil?
        db_user = @db_connector.finduser(user_name)
        if db_user
          creator_gender = db_user.gender
          # create of find ranking
          class_item = @db_connector.find_or_create_classifica( game_name, db_user.id )
          if class_item
            nal_server.db_connector = @db_connector
            nal_server.set_userdb_info(user_name, db_user)
            creator_score = class_item.score
          else
            @log.warn "Ranking #{game_name} not found in db for user with #{db_user.id}"
            info["class"] = false # user not on ranking 
          end
        else
          info["class"] = false #user not in db can't play for ranking
          @log.warn "Player #{user_name} not found in db..."
        end
      end #end db_connector
    
      # set option in the core game
      nal_server.set_option_info(info)
      # check if options are set correctly
      nal_server.check_option_range
      pgi = PgItem.new(game_name, info["opt_game"])
      pgi.add_creator_info(conn, user_name, creator_gender, creator_score)
      
      # pin
      pin_to_set = nil
      if info["prive"]["val"] == true
        pin_to_set = info["prive"]["pin"]
        @log.debug "Game is private, pin: #{pin_to_set}"
        pgi.pin_originator = pin_to_set
      end
    
      pgi.scored_game = info["class"]
      pgi.nal_server = nal_server

      #save pgitem also in db
      if pg_index == -1
        unless @db_connector.nil?
          begin
            pg_index = CupDbDataModel::CupPgItem.create_pgitem(pgi, user_id, @db_connector.active_pg_conn)
            @log.debug("Created a pgitem in db with id #{pg_index}")
          rescue => detail
            @log.error("Unable to insert pgitem in db #{$!}\n")
            conn.send_data(build_cmd(:pg_create_reject, "Errore nel salvataggio del nuovo gioco")) if conn
            return nil
          end
        end    
      end
      # add pg_item to the list
      pg_index = add_pg_item_tolist(pgi, pg_index) 
      unless pg_index
        @log.error("Error on add_pg_item_tolist: no index available?(#{@pg_index_arr.size})")
        conn.send_data(build_cmd(:pg_create_reject, "pg_create: errore in add_pg_item_tolist")) if conn
        return nil 
      end
      nal_server.set_pgindex(pg_index)

      # broadcast information about the pg_item
      if conn
        inform_all_about_new_pg2(pg_index, pgi)
      end
      
      if conn
        utenti = 'utenti'
        utenti = 'utente' if num_clients == 1
        conn.send_data(build_cmd(:info, "Richiesta di partita creata con indice #{pg_index}, vista da #{num_clients} #{utenti}."))
      end

      return pgi
    end
  
    ##
    # Build the yaml message for join reject
    def build_msg_pg_join_reject2(pg_index, error_code)
      info = JSON.generate({:ix => pg_index, :err_code => error_code})
      msg = build_cmd(:pg_join_reject2, info)
    end
  
    def get_pg_item(pg_index)
      return @pg_list[pg_index]
    end
    
    ##
    # Client want to join a pg
    # conn: connection that generate the request
    # pg_index: index on pg list
    def join_req_part1(conn, pg_index)
      pg_item = @pg_list[pg_index]
      unless pg_item
        # error
        msg = build_msg_pg_join_reject2(pg_index, 1)
        conn.send_data msg
        @log.debug "Reject request because #{pg_index} not found"
        return
      end
    
      errno = pg_item.is_join_req_part1_ok?(conn)
      if errno > 0
        @log.debug "Reject request because #{errno} on is_join_req_part1_ok?"
        msg = build_msg_pg_join_reject2(pg_index, errno)
        conn.send_data msg
        return
      end
    
      # join colud be acceptable, inform the creator
      # what about if another user want to join? Don't accept the join and invite
      # user to retry
      if pg_item.is_tender_submitted?(conn.user_name) 
        msg = build_cmd(:info, "Al gioco N.#{pg_index} e' gia' stata eseguita una richiesta.")
        conn.send_data msg
        return
      elsif !pg_item.is_possible_to_tender?
        @log.debug "NO more tender are admitted"
        msg = build_msg_pg_join_reject2(pg_index, 5)
        conn.send_data msg
        return
      end
      # may be there is a need to lock the pg_index until the creator send back a response.
      conn_creator = pg_item.creator_conn
      # if conn_creator == nil 
      #   # something is wrong the user is no more available
      #   msg = build_msg_pg_join_reject2(pg_index, 6)
      #   conn.send_data msg
      #   # remove this pg_item
      #   pg_list_remove_index_reuse(pg_index)
      #   @log.error("Inconsistence in pg_list, user logged out but pg_item still pending")
      #   return
      # end
      # send a tender request to the creator
      if conn_creator != nil
        #allow join also on offline creator
        msg = build_cmd(:pg_join_tender, "#{conn.user_name},#{pg_index}")
        conn_creator.send_data msg
      end
      
      pg_item.add_tender(conn)
      
    end
  
    def join_req_private(conn, pg_index, pin)
      pg_item = @pg_list[pg_index]
      if pg_item
        pg_item.set_pin_given( conn.user_name, pin)
      end
      join_req_part1(conn, pg_index)
    end
  
    ## Creator send back a join ok to a tender request
    # return a new  instance of GameInProgressItem if the game can start
    def joinok(conn, tender_user_name, pg_index, conn_tender)
      pg_item = @pg_list[pg_index]
      unless pg_item
        # error
        @log.debug "pg_item of #{pg_index} not found"
        msg = build_msg_pg_join_reject2(pg_index, 7)
        conn.send_data msg
        return nil
      end
      errno = pg_item.is_joinok_ok?(conn, conn_tender)
      if errno > 0
        @log.debug "error #{errno} on check is_joinok_ok"
        msg = build_msg_pg_join_reject2(pg_index, errno)
        conn.send_data msg
        return nil
      end
      msg = build_cmd(:pg_join_ok, "#{pg_index}")
      conn_tender.send_data msg
      # add tender as player 
      pg_item.add_player(conn_tender)
      #check if it is a ranking game
      if pg_item.scored_game
        # add user info from db into the nal server
        unless @db_connector.nil?
          db_user = @db_connector.finduser(conn_tender.user_name)
          if db_user
            # create of find ranking
            class_item = @db_connector.find_or_create_classifica( pg_item.game, db_user.id )
            if class_item
              pg_item.nal_server.set_userdb_info(conn_tender.user_name, db_user)
            else
              @log.error("Classifica item not found for #{conn_tender.user_name}, #{pg_item.game}, #{db_user.id}")
            end
          else
            @log.error("User not found in db #{conn_tender.user_name}")
          end
        end
      end
    
      # now check if the game can start
      if pg_item.nal_server.game_canstart?(pg_item)
        # game can start
        @log.debug("Game N.#{pg_index} can start")
      
        # get the player list
        player_list = pg_item.get_players_username_list
        player_list_conn = pg_item.get_players_connected
        if player_list.size != player_list_conn.values.size
          str_err = "Player list #{player_list.size} is not equal to connected players list (#{player_list_conn.values.size})"
          @log.error str_err
          raise str_err
        end
      
        # pending game becomes game in progress
        game_in_pro = GameInProgressItem.new(player_list, pg_item.nal_server, pg_index)
        player_list_conn.each do |tmp_user_name, conn_tmp|
          #p tmp_user_name
          game_in_pro.set_connection(tmp_user_name, conn_tmp)
        end
        # remove index from pg list without reusing index 
        pg_list_remove_index(pg_index)
        player_list.each do |pl| 
          unsubscribe_user_pglist(pl)
        end
        # remove players in the list from pending game, beacuse they can play only one game at once
        pg_list_remove_playerlist(player_list)
        return game_in_pro
      else
        @log.debug "Can't start the game on pg_item"
      end
      return nil
    end
  end#end class PendingGameList  

end#end module


if $0 == __FILE__
  require "test/test_common"
  
  include Log4r
  log = Log4r::Logger.new("serv_main")
  log.outputters << Outputter.stdout 
  pg_list = MyGameServer::PendingGameList.new('')
  conn = FakeUserConn.new
  conn.user_name = 'marta'
  conn2 = FakeUserConn.new
  conn2.user_name = 'marco'
  pg_list.subscribe_user_pglist(conn2)
  pg_list.pending_games_req_list2(conn)
  
  basic_conn = MyGameServer::BasicDbConnector.new
  pg_list.set_db_connector(basic_conn.db_connector)
  
  info_game = {:game => 'Mariazza', :class => false, :opt_game => {:target_points_segno => {:val => 41}, :num_segni_match => {:val => 4}}, :prive => {:val => false}}
  pg_list.pending_game_create2(conn, info_game, 5, conn.user_name, conn.user_id, 1)
  #pg_list.pending_game_removereq(conn, "9")
end

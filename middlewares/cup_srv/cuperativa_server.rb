# file: cuperativa_server.rb

$:.unshift File.dirname(__FILE__)

require 'rubygems'

require 'singleton'
require 'log4r'
require 'pg_list'
require 'pg_item'
require 'game_in_prog_item'
require 'nal_srv_algorithm'
require 'database/dbconnector'
require 'database/cup_pgitem'
require 'database/sendemail_errors'
require 'network/prot_buildcmd'
require 'viewgame_list'
require 'yaml'
require 'json'

# Aggiungere un nuovo gioco
# 5) modifica il server
# 5.a) In pg_list.rb aggiungi un require nalgames/mynewgame
# 5.b) In pg_list.rb aggiungi il nuovo hash in @@games_available
# 5.c) Crea il file NalServer.... <mynewgame>, prestando attenzione alla funzione update_ranking
# La tabella della classifica nel db va creata usando il progetto rails della cuperativa
# (vedi doc cuperativa_invido_it.txt)
# 6) Oltre al progetto in rails, va aggiornato il CupDbDataModel aggiungendo una classifica per il gioco nuovo
# 6.a) DbDataConn.find_or_create_classifica deve supportare la nuova classifica, altrimenti si gioca senza classifica
# 6.b) Aggiungere la nuova classifica con la funzione default_classifica nel file dbcup_datamodel.rb


include Log4r



module MyGameServer



#########################################################################
#########################################################################
################################################## class CuperativaServer
##
# Cuperativa server main class
# Connection manager
class CuperativaServer
  attr_reader :serv_settings
  
  include Singleton
  include ProtBuildCmd # for build_cmd

  
  def initialize
    @dir_log = File.dirname(__FILE__) + "/serverlogs"
    # NOTE: initialize here all loggger because with sinitra there is only a file logger
    #       each logger is used somewer in the application
    Log4r::Logger.new("coregame_log")
    Log4r::Logger['coregame_log'].outputters << Outputter.stdout
    Log4r::Logger.new("DbConnector")
    Log4r::Logger['DbConnector'].outputters << Outputter.stdout
    @log = Log4r::Logger.new("serv_main")
    Log4r::Logger['serv_main'].outputters << Outputter.stdout
    @serv_settings = {}
    @settings_default = {
      :login_email => '',
      :password_email => '', :publickey_server => '', :secret_server => '',
      :logpath => 'serverlogs',
      :target => :development,
      :database => {
        :user_db => 'cup_user',
        :pasw_db => '',
        :adapter => :postgres,
        :db_name => 'cupuserdatadb',
        :host => 'localhost',
        :port => 5432
      },
      :connhandler_opt => { }
    }
    @settings_filename = File.dirname(__FILE__)  + '/options.yaml' 
    
    # connected player clients, use connection hash to identify it
    @clients = {}
    # list of players that want play a game or are playing a game
    @tables = []
    @stdlog = $stderr
    # list of all logged in players. Use user_name to identify a user (key)
    #      as value is used the connection
    @logged_in_list = {}
    
    # list of subscribed user data info.Use user_name to identify a user
    @subscribed_userdata_list = {}
    
    # game in progress list. Hash with key index and value instance of GameInProgressItem
    # GameInProgressItem is an alias for Table of game
    @game_in_progress = {}
    
    # init random seed
    srand(Time.now.to_i)

    load_settings
    
    init_log

    @pg_list =  PendingGameList.new(@dir_log)
    @viewgame_list = ViewGameList.new(@dir_log)
  end

  def load_settings
    yamloptions = {}
    prop_options = {}
    yamloptions = YAML::load_file(@settings_filename) if File.exist?( @settings_filename )
    prop_options = yamloptions if yamloptions.class == Hash
    @settings_default.each do |k,v|
      if prop_options[k] != nil
        # use settings from yaml
        @serv_settings[k] = prop_options[k]
      else
        # use default settings
        @serv_settings[k] = v
      end
    end
    #p @serv_settings  
  end

  def init_log
    if @serv_settings[:target] == :production
        @log.level = INFO
    end
  end

  def init_pg_list_fromdb
    pgitems_indb = CupDbDataModel::CupPgItem.find_pgitems(@db_connector.active_pg_conn)
    return if pgitems_indb == nil
    n_days  = 1 # validity of pgitem
    pgitems_indb.each do |pg|
      if Time.now > pg.updated_at + n_days * 86400 
        @log.debug "pg item #{pg.id} is expired"
        pg.delete_me(@db_connector.active_pg_conn)
        next
      end
      if pg.status == 'game_not_started'
        user = CupDbDataModel::CupUser.find_by_id(pg.owner_user_id, @db_connector.active_pg_conn)
        if user
          @pg_list.pending_game_create2(nil, eval(pg.options), 0, user.login, user.id, pg.id)
        end
      elsif pg.status == 'game_started'
        # TODO
        @log.warn("TODO implement pgitem game in progress - game_started")
      end
    end
    @log.debug "Initialize pg list with #{@pg_list.get_num_items} pg-items"
  end
  
  ##
  # Reset the server (until now used only on unit test)
  def reset_server
    # connected player clients, use connection hash to identify it
    @clients = {}
    # list of players that want play a game or are playing a game
    @tables = []
    # list of all logged in players. Use user_name to identify a user (key)
    #      as value is used the connection
    @logged_in_list = {}
    # list of subscribed pending game info. Use user_name to identify a user
    @viewgame_list = ViewGameList.new(@dir_log)
    # list of subscribed user data info.Use user_name to identify a user
    @subscribed_userdata_list = {}
    # pending game list. Hash with key index and value instance of PgItem
    @pg_list =  PendingGameList.new(@dir_log)
    # game in progress list. Hash with key index and value instance of GameInProgressItem
    # GameInProgressItem is an alias for Table of game
    @game_in_progress = {}   
  end
  
  def connect_to_db
    begin
      @log.debug "Connect to database"
      basic_conn = MyGameServer::BasicDbConnector.new
      @db_connector = basic_conn.db_connector
      @pg_list.set_db_connector(@db_connector) 
      init_pg_list_fromdb
    rescue => detail
      @log.error("ERROR on server: #{$!}\n")
      @log.error(detail.backtrace.join("\n"))
      @db_connector = nil
    end
  end
  
  ##
  # Error log
  def error(detail)
    @log.error("ERROR on server:")
    @log.error(detail.backtrace.join("\n"))
    # send also an email for this kind of errors
    sender = EmailErrorSender.new(@log)
    sender.send_email("#{$!}\n" + detail.backtrace.join("\n"))
  end
  
  ##
  # True if the login name of the player is accepted
  # name: login name
  # passw: password
  # token: token used instead of password
  # conn: Connection instance (websocket from UserConnHandler)
  def accept_name?(name, passw, token, conn)
    dbuser = @db_connector.get_user_by_auth(name, passw, token)
    if dbuser != nil
      # player accepted because is not yet on the lobby
      old_conn = @logged_in_list[name]
      if old_conn
        @log.warn "old connection on #{name} overwritten by a new login"
        msg = build_cmd(:info,"un login con lo stesso user name ti ha mandato via.")
        old_conn.send_data msg
        old_conn.close_connection_after_writing
      end
      @logged_in_list[name] = conn
      # at this point conn.user_name is not yet set
      return dbuser
    else
      @log.debug "User authentication failed for #{name} and password #{passw}"
      return nil # password, token or login error
    end
  end

  # Insert user into the db
  def insert_user(opt, conn)
    user_id = @db_connector.create_user(opt)
    @logged_in_list[opt[:login]] = conn
    return user_id
  end

  def user_exist?(loginname)
    @db_connector.user_exist?(loginname)
  end
  
  ##
  # set the guest connection
  def set_guest_connected(name, conn)
    unless @logged_in_list[name]
      @logged_in_list[name] = conn
      return 0
    end
    # error user guest already connected
    return 3
  end
  
  ##
  # Send command to all client connected
  def send_cmd_to_all(cmd_for_all)
    @logged_in_list.each_value{|cl| cl.send_data(cmd_for_all)}
  end
  
  ##
  # Add a new connection
  # conn: an instance of CuperativaUserConn
  def add_conn( conn )
    @clients[conn.hash] = conn
    log "Player online #{@clients.size}" 
  end
  
  ##
  # Remove connection
  # conn: CuperativaUserConn to be removed
  def remove_connection( conn )
    log "Remove socket player #{conn.user_name}"
    
    @clients.delete(conn.hash)
    on_userlogged_out(conn)
    
    log "Player online #{@clients.size}" 
  rescue => detail
    log "remove_connection error(#{$!})"
    error(detail)
  end

  def on_userlogged_out(conn)
    pl_name = conn.user_name
    @logged_in_list.delete(pl_name)
    @viewgame_list.remove_connection( conn )
    @pg_list.remove_connection( conn )
    
    @subscribed_userdata_list.delete(conn.user_name)
    # check if the player was on game and inform his opponnent
    @game_in_progress.each do |g_ix, gam_inp|
      gam_inp.connection_removed(conn)
    end
    inform_all_about_user_logout(conn)
  end
  
  ##
  # Client require an user list
  def user_req_list(conn_req)
    # build a response command
    @subscribed_userdata_list[conn_req.user_name] = conn_req
    count  = 0
    # step slice, when we have reach this number we send the list 
    step = 40
    cmd_det = ""
    list_nr = "0"
    list_next = "1"
    num_user = @logged_in_list.size
    @log.debug "user_req_list with logged in players: #{num_user}" 
    str_rec_coll = "" 
    # if the list is empty we send a special empty
    if num_user == 0
      cmd_det = "0,empty,empty;"
      # send an empty list
      conn_req.send_data(build_cmd(:user_list, cmd_det))
      return
    end
    sent_flag = false
    @logged_in_list.each do |k, v|
      str_rec = "#{k},#{v.user_lag},#{v.user_type},#{v.user_stat};"
      str_rec_coll += str_rec
      count += 1
      if count >= num_user
        # last item in the list, send it
        cmd_det = "#{list_nr},eof;#{str_rec_coll}"
        conn_req.send_data(build_cmd(:user_list, cmd_det))
        sent_flag = true
      elsif(count % step)  == 0
        # reach a maximum block, send records
        cmd_det = "#{list_nr},#{list_next};#{str_rec_coll}"
        conn_req.send_data(build_cmd(:user_list, cmd_det))
        str_rec_coll = ""
        list_nr = list_next
        list_next = (list_next.to_i + 1).to_s
        sent_flag = true 
      end  
    end
    unless sent_flag
      @log.error("user_req_list sent nothing!!")
    end
  end
  
  ###
  ## Player request pending game list using interface 2
  def pending_games_req_list2(conn)
    @pg_list.pending_games_req_list2(conn)
  end
  
  ##
  # Request to remove a pending game
  # conn: user connection
  # msg_details: game index
  def pending_game_removereq(conn, msg_details)
    pg_ix = msg_details.to_s
    @pg_list.pending_game_removereq(conn, pg_ix)
  end
  
  ##
  # Create a new pending game
  # conn: user connection
  # info: 
  def pending_game_create2(conn, info)
    num_clients = @logged_in_list.size
    @pg_list.pending_game_create2(conn, info, num_clients, conn.user_name, conn.user_id, -1)
  end
  
  ##
  # Inform that a new user has joined the server
  def inform_all_about_newuser(conn)
    if @subscribed_userdata_list.size > 0
      str_det = "#{conn.user_name},#{conn.user_lag},#{conn.user_type},#{conn.user_stat}"
      msg = build_cmd(:user_add, str_det)
      @subscribed_userdata_list.values.each{|conn| conn.send_data msg}
    end
  end

  def inform_all_about_user_logout(conn)
    if @subscribed_userdata_list.size > 0
      str_det = JSON.generate({:name => conn.user_name})
      msg = build_cmd(:user_removed, str_det)
      @subscribed_userdata_list.values.each{|conn| conn.send_data msg}
    end
  end
   
  ##
  # Client want to join a private game
  def join_req_private(conn, pg_index, pin)
    @pg_list.join_req_private(conn, pg_index, pin)
  end
  
  ##
  # Client want to view a current game
  def game_view_parse_cmd(conn, msg_details)
    cmd = msg_details["cmd"]
    if cmd == "start_view"
      gip = @game_in_progress[ix]
      @viewgame_list.game_view_start_view(conn, msg_details[:index], gip)
    elsif cmd == "stop_view"
      # TODO 
      @log.warn "Ignore game view command #{cmd}" 
    elsif cmd == "req_list"
      @viewgame_list.view_games_req_list2(conn, @game_in_progress)
    else
      @log.warn "Game view command #{cmd} from #{msg_details} not recognized"
    end    
  end
  
  def join_request(conn, pg_index)
    @pg_list.join_req_part1(conn, pg_index)
  end
  
  ##
  # Tender was accepetd by pg creator
  # conn: connection of pg creator
  # tender_user_name: user name of tender
  # pg_index: pg index as string
  def joinok(conn, tender_user_name, pg_index)
    pg_item = @pg_list.get_pg_item(pg_index)
    conn_tender = @logged_in_list[tender_user_name]
    if conn_tender == nil
      @log.debug "joinok: #{tender_user_name} is not logged in "
      return
    end
    if pg_item
      player_list = pg_item.get_players_username_list
      game_in_pro = @pg_list.joinok(conn, tender_user_name, 
                     pg_index, conn_tender)
      
      if game_in_pro
        @game_in_progress[pg_index] = game_in_pro
        player_list.each{|name| @viewgame_list.unsubscribe_user_game_view(conn.user_name)}
        # start the network game
        @log .debug "Start a network game"
        #p [:network_game, game_in_pro]
        begin
          start_network_game(game_in_pro)
        rescue => detail
          @log.error("Unable to start_new_game #{$!}\n")
          msg = @pg_list.build_cmd(:srv_error, @pg_list.srv_error_code(:pg_start_error))
          conn.send_data msg
        end
      end
    else
      @log.error("Game ix#{pg_index} not found")
    end
  end
  
  ##
  # Need to advance all game in progress
  def process_game_in_progress
    @game_in_progress.each do |k,game_item|
      game_item.do_core_process
    end
  end
  
  ##
  # Send the command cmd to all players inside the game in progress item
  def send_cmd_to_gameinpro(ix_game, cmd)
    g_inp = @game_in_progress[ix_game]
    if g_inp
      g_inp.players.each do |user_name|
        conn = @logged_in_list[user_name]
        conn.send_data cmd if conn != nil
      end
    end
  end
  
  ##
  # Player connect into the server, check if it was into a game and have
  # temporarly disconnected
  def game_inprog_player_reconnect?(conn)
    @game_in_progress.each do |g_ix, gam_inp|
      if gam_inp.is_player_disconnectedhere?(conn.user_name)
        gam_inp.player_reconnect(conn)
        return gam_inp
      end
    end
    return nil
  end

  def is_user_owner_of_pgitem?(conn)
    return @pg_list.check_if_user_is_pgitem_owner(conn.user_name)
  end

  def game_inprog_playerleave(user_name, g_ix, gam_inp)
    @log.debug("Player #{user_name} leave the table on game #{g_ix}")
    str_det = "#{g_ix},#{user_name}"
    cmd = build_cmd(:leave_table_ntfy, str_det)
    gam_inp.players.each do |tmp_user_name|
      conn = @logged_in_list[tmp_user_name]
      conn.send_data cmd if conn
    end
    
    gam_inp.player_abandon(user_name)
    gam_inp.player_leaved(user_name, :leave_the_table)
  end
    
  ##
  # Player disconnect a  game_inprog
  def game_inprog_player_disconnect(user_name, g_ix, gam_inp, reason)
    @log.debug("#{user_name} is leaving game in progress #{g_ix} because #{reason}")
    num_players_on_table = gam_inp.player_disconnect(user_name, reason)
    if num_players_on_table <= 0
      # nobody on this game in progress, remove it
      #@game_in_progress.delete(g_ix)
      #@pg_list.reuse_pg_index(g_ix) # TODO cleanup the game after time elapsed. (1 day?)
    else
      # there are still players on this game in progress
      # inform it
      str_det = "#{g_ix},#{user_name}"
      cmd = build_cmd(:leave_table_ntfy, str_det)
      gam_inp.players.each do |tmp_user_name|
        conn = @logged_in_list[tmp_user_name]
        conn.send_data cmd
      end
    end
  end
   
  ##
  # Start a newtwork game
  # game_in_pro: GameInProgressItem item
  def start_network_game(game_in_pro)
    players_nal = []
    # prepare information for core nal
    game_in_pro.players.each do |user_name|
      conn = @logged_in_list[user_name]
      if conn == nil
        game_in_pro.player_disconnect(user_name, :disconnect)
        return
      end
      # we use only one game in progress pro connection, that mean that only
      # one game can be handled by client. I think this is good and avoid 
      # simultaneus games. game_in_pro in conn is needed to handle messages
      # like alg_player_declare
      conn.game_in_pro = game_in_pro
      # set the type name of the game
      #alg = NAL_Srv_Algorithm.new(conn, self, game_in_pro)
      # we need a customizable nal algorithm, beacuse also when the interface
      # still remain the same, object inside on it are different, dipending on the game
      #p game_in_pro.nal_server.nal_algorithm_name
      alg = eval(game_in_pro.nal_server.nal_algorithm_name).new(conn, game_in_pro)
      alg.name_core_game = game_in_pro.nal_server.name_core_game
      players_nal << { :algorithm => alg, :user_name => user_name   }
    end
    # now start the game on core nal
    game_in_pro.nal_server.start_new_game(players_nal)
  end
  
  ##
  # Unsubscribe username  from userdata list observer
  def unsubscribe_user_userdatalist(user_name)
    @subscribed_userdata_list.delete(user_name)
  end
  
  ##
  # Check if clients are alive
  def ping_clients
    #@log.debug "Wanna ping..."
    # ping all clients only when they are a small number
    # In the future we can  check an unactivity list and ping only lazy client
    
    zombies = []
    #@logged_in_list.each_value do |client|
    @clients.each_value do |client|
      if client.ping_is_pending?
        zombies << client
        next
      end
      client.send_ping()
      sleep 0.2
    end
    # remove zombies connections
    zombies.each do |zcon|
      @log.debug "Close zombie connection #{zcon.user_name}" 
      zcon.close_connection 
    end
    #end
  end
  
  ##
  # Log
  def log str
    @log.info str
  end
  
  
end #end CuperativaServer


end #end module

if $0 == __FILE__
  log = Log4r::Logger.new("serv_main")
  log.outputters << Outputter.stdout 
  main_my_srv = MyGameServer::CuperativaServer.instance
  main_my_srv.log("Test OK")
  main_my_srv.connect_to_db
  main_my_srv.log("server connection OK")
end

# -*- coding: ISO-8859-1 -*-
# file: cuperativa_bot.rb
# file used to create a robot that play online games

$:.unshift(File.expand_path( File.join(File.dirname(__FILE__), '../cup_srv')))
$:.unshift File.dirname(__FILE__)

require 'rubygems'

require 'log4r'
require 'singleton' 
require 'socket'
require 'yaml'
require 'network/prot_parsmsg'
require 'network/client/control_net_conn'
require 'network/client/model_net_conn'
require 'base/core/gameavail_hlp'

# bots games
require 'gamesbot/bot_testrestart'


include Log4r

#### Do you want to add a new bot?
# make something similar to bot_briscola folder:
#    new dir bot_<newgame>, new file: bot_<newgame>.rb
#    daemon_robot.rb that load bot_<newgame>.rb
#    robot.yaml with the <newgame>
# Add in CuperativaBot <newgame> into @all_games_bots

##
# Bot that play an online game automatically without gui
class CuperativaBot
  attr_reader :current_game_gfx, :app_settings
  attr_accessor :settings_filename
  
  def initialize
    @log = Log4r::Logger.new("coregame_log")
    @log.outputters << Outputter.stdout
    @login_name = 'marco'
    @server_ip = '192.168.33.1'
    @server_port =  20606
    @playfor_classment = false
    # should the robot join an available pg game?
    @join_game = false
    @game_to_join = nil
    # game info to be played
    # NOTE:  :key is the same :name as in game_info.yaml
    @game_bot_name = 'GameBasebot'
    @all_games_bots = [ 
       {:core_name => "CoreGameBriscola", :alg_name => "AlgCpuBriscola", :key => :briscola_game,:nalgfx_name =>'NalClientGfx'},
       {:core_name => "CoreGameMariazza", :alg_name => "AlgCpuMariazza", :key => :mariazza_game,:nalgfx_name =>'NalClientGfx'},
       {:core_name => "CoreGameSpazzino", :alg_name => "AlgCpuSpazzino", :key => :spazzino_game,:nalgfx_name =>'NalClientSpazzinoGfx'},
       {:core_name => "CoreGameTombolon", :alg_name => "AlgCpuTombolon", :key => :tombolon_game,:nalgfx_name =>'NalClientSpazzinoGfx'},
       {:core_name => "CoreGameScopetta", :alg_name => "AlgCpuScopetta", :key => :scopetta_game,:nalgfx_name =>'NalClientSpazzinoGfx'},
       {:core_name => "CoreGameBriscolone", :alg_name => "AlgCpuBriscolone", :key => :briscolone_game,:nalgfx_name =>'NalClientGfx'},
       {:core_name => "CoreGameTressette", :alg_name => "AlgCpuTressette", :key => :tressette_game, :nalgfx_name =>'NalClientGfx'},
       {:core_name => "CoreGameTressettein4", :alg_name => "AlgCpuTressettein4", :key => :tressettein4_game, :nalgfx_name =>'NalClientGfx'},
    ]
    @game_to_play = @all_games_bots[0] 
    @settings_filename =  File.join(File.dirname(__FILE__), 'robot.yaml')
    @settings_default = {
      :engine => 'Briscola', 
      :login => 'robot1',
      :password => '', 
      :playfor_classment => false,
      :admin_port => 3001,
      :ws_prefix => 'ws',
      :server_ip => '127.0.0.1', :server_port =>  3000, 
      :wait_time_info => { :enabled => true, :havetoplay_time => 0.600},
      :log_level => :production, # values: :production, :develop
      :debug_server_messages => false,
      :join_curr_game => false,
      :scopetta_game => {:alg_level => :master},
      :briscola_game  => {:alg_level => :dummy},
      :mariazza_game  => {:alg_level => :dummy},
      :spazzino_game  => {:alg_level => :dummy},
      :tombolon_game  => {:alg_level => :dummy},
      :briscolone_game  => {:alg_level => :dummy},
      :tressette_game  => {:alg_level => :dummy},
      :game_bot_classname => 'GameBasebot'
    }
    @app_settings = {}
    @current_game_gfx = nil
    @state_pg_create = :init
    # thread run
    @proc_thread_run = nil
    # robot supported games
    @supported_games = []
    
  end

  def log_debug
    if @app_settings[:log_level] == :develop_withfile
      id = "#{@app_settings[:login]}-#{Time.now.to_i}"
      set_dir_and_logfilename(id)
      FileOutputter.new('coregame_log', :filename=> @out_log_name) 
      Logger['coregame_log'].add 'coregame_log'
    end
  end
  
  def get_nameprog_swversion
    nomeprog = "CuperativaBot"
    ver_prog = [0,0,0]
    return nomeprog, ver_prog
  end
  
  ##
  # Set the logger for the production env
  def log_production
    #@log.outputters << Outputter.stdout
    set_dir_and_logfilename(Time.now.to_i)
    FileOutputter.new('coregame_log', :filename=> @out_log_name) 
    myApacheLikeFormat = PatternFormatter.new(:pattern => "[%d] %m") # questo usa [data] <testo>
    mybaseApacheLikeLog = RollingFileOutputter.new 'coregame_log', 
          :maxsize => 999999999, 
          :maxtime => 86400 * 7, # tempo in secondi (1 * 14 giorni). Dopo 14 giorni avviene il rollout e 
                                  # quindi viene creato un nuovo file
          :filename => out_log_name, 
          :trunc => false, # se true viene usato 'w' in File.open, altrimenti con false 'a'  
                           # voglio 'a' in quanto ogni volta che viene chiamato lo script, devo avere un append
          :formatter => myApacheLikeFormat

    
    Log4r::Logger['coregame_log'].add 'coregame_log'
    Log4r::Logger['coregame_log'].level = INFO
  end

  def set_dir_and_logfilename(id)
    dir_log = File.expand_path(File.join(File.dirname(__FILE__), '../cup_srv/serverlogs/'))
    @out_log_name = File.join(dir_log, "robot-#{id}.log")
  end
  
  ##
  # Load all supported games
  def load_supported_games
    @supported_game_map = InfoAvilGames.info_supported_games(@log)
    #@supported_game_map.each{|k,v| p k}
    #p @supported_game_map
    # execute require 'mygame'
    @all_games_bots.each do |botgame|
      infogame =  @supported_game_map[botgame[:key]]
      if infogame != nil and infogame[:enabled] == true
        botgame[:name] = infogame[:name]
        botgame[:opt] = infogame[:opt]
      else
        @log.warn("Game bot key #{botgame[:key]} not enabled in game_info")
      end
    end
    #p @all_games_bots
  end #end load_supported_games
  
  ##
  # Run the boot
  def run
    #p @app_settings
    if @app_settings[:log_level] == :develop || 
      @app_settings[:log_level] == :develop_withfile
      log_debug
    end
    #puts YAML.dump(@settings_default)
    @join_game = @app_settings[:join_curr_game]
    @game_bot_name = @app_settings[:game_bot_classname]
    # load option on supported games
    load_supported_games
    
    @control_net_conn = ControlNetConnection.new(self)
    @model_net_data = ModelNetData.new
    @model_net_data.add_observer("cuperativa_gui", self)
    @model_net_data.add_observer("control_net", @control_net_conn)
    @control_net_conn.set_model_view(@model_net_data, self)
    # ready to use the model
    @model_net_data.event_cupe_raised(:ev_gui_controls_created)
    
    # connect to the server
    info_conn_hash = {}
    @control_net_conn.prepare_info_conn_hash(info_conn_hash)
    info_conn_hash[:host_server] = @server_ip
    info_conn_hash[:port_server] = @server_port
    info_conn_hash[:login_name] = @login_name
    info_conn_hash[:password_login_md5] = @password_login_md5
    info_conn_hash[:admin_port] = @app_settings[:admin_port]
    info_conn_hash[:ws_prefix] = @app_settings[:ws_prefix]
    
    if @app_settings[:debug_server_messages] == true
      @control_net_conn.server_msg_aredebugged = true
    end
    
    #p info_conn_hash
    #p @app_settings
    @control_net_conn.connect_to_remote_server(info_conn_hash)
    @proc_thread_run = Thread.new{
      begin
        @state_game = :initial
        while @state_game != :end
          # process game
          if @current_game_gfx
            @current_game_gfx.do_core_process
          end
          @control_net_conn.process_next_server_message
          sleep 0.1 #use sleep to avoid cpu overload
        end
        sleep 0.1 #use sleep to avoid cpu overload 
      rescue => detail
        @log.error "Process server message error (#{$!})\n"
        @log.error detail.backtrace.join("\n")
      end
    }

    
  end
  
  def join_run
    @proc_thread_run.join
  end
  
  def exit
    @log.debug "Exit with state_game = end"
    @state_game = :end
  end
  
  ##
  # Initialize the game bot. Called when the network is started.
  def initialize_current_gfx(nome_game)
    @log.debug "**** bot: initialize current gfx #{nome_game}"
    #p self.app_settings
    select_engine(nome_game)
    #@current_game_gfx = eval(@game_to_play[:class_name]).new()
    # override @game_bot_name only to use a test robot. For a game GameBasebot is enought
    # simply add the new game to @all_games_bots
    
    @current_game_gfx = eval( @game_bot_name ).new #GameBasebot.new
    @current_game_gfx.set_game_info(@game_to_play[:core_name],
                        @game_to_play[:alg_name], @game_to_play[:key],
                        @game_to_play[:nalgfx_name],
                        @login_name)
    @current_game_gfx.net_controller = @control_net_conn
    @current_game_gfx.join_game = @join_game
    #p self.app_settings
  end
  
  ##
  # Logged on notification
  def ntfy_state_logged_on
    @log.debug 'bot: logged on'
    @game_to_join = nil
  end
  
  def ntfy_state_no_network
    @log.info 'No network, nothing to do now, exit for me'
    exit
  end

  def ntfy_state_exit
    @log.info 'Server is disconnected, exit for me'
    exit
  end
  
  def ntfy_state_on_netgame
    log_info 'bot: net game started'
    @state_pg_create = :on_game
  end
  
  def  ntfy_state_ontable_lessplayers
    if @current_game_gfx.leave_on_less_players?
      log_info 'bot: less player, leave table e create new games'
      @control_net_conn.leave_table_cmd
      @control_net_conn.game_window_destroyed
      create_or_join_a_game
    else
      @log.debug "Less player wait for substitute"
    end
  end
  
  def join_current_pg_game
    #p @game_to_join
    ix_game = @game_to_join["index"]
    @log.debug "join current game: #{ix_game}, from user #{@game_to_join["user"]}"
    
    @log.debug "auto_join game : #{ix_game}"
    @control_net_conn.send_join_pg(ix_game)
  end
  
  ##
  # Here the bot create the new game request for each supported games
  def create_new_pg_game
    @log.debug "bot create_new_pg_game on state #{@state_pg_create}, supported games num: #{@supported_games.size}"
    if @state_pg_create != :submitted
      #p @supported_games
      @supported_games.each do |item|
        if item[:name] == nil
          @log.warn "Ignore to send game creation without a name maybe it is disabled in game_info, item is #{ObjTos.stringify(item)}"
          next
        end
        @log.debug "Submit pg game on #{item[:name]}"
        #msg_det = "#{item[:name]},#{item[:stropt]}"
        info =  {
          :game => item[:name],
          :prive => {:val => false, :pin => '' },
          :class => @playfor_classment,
          :opt_game => item[:opt] 
        }
        @log.debug "auto_create_new_game, pg_create2: #{ObjTos.stringify(info)}"
        @control_net_conn.send_create_pg2(info)
      end
      @state_pg_create = :submitted
    end
  end
  
  ## Network_cockpit_view callbacks
  # pending games

  def clear_pgtable
  end
  
  def pushfront_pgitem_data2(list_data)
    unless @game_to_join 
      @game_to_join = find_first_supported_game(list_data)
      unless @game_to_join
        @log.warn "Game not found in this slice #{list_data}\n Supported games: (#{@supported_games})"
      end
    end
  end
  
  def find_first_supported_game(list_data)
    list_data.each do |pg_item|
      name_pg_item = pg_item["game"]
      @supported_games.each do |supp_item|
        if name_pg_item == supp_item[:name].to_s
          @log.debug "found a pg_item supported"
          return pg_item
        end
      end
    end
    return nil
  end
  
  def table_add_pgitem(ix_game)
  end
  def table_add_pgitem2(ix_game)
    @log.debug "add pg game: #{ix_game}"
  end
  
  def table_remove_pg_game(ix_data)
  end
  
  #user data
  def clear_userlist_table
  end
  
  # User data received
  # last_user: array of user. e.g: [{:type=>"G", :stat=>"-", :lag=>"5", :name=>"robot_1"}, {:type=>"G", :stat=>"-", :lag=>"5", :name=>"ospite1"}]
  def pushfront_users_data(arr_user)
    #p arr_user
    @log.debug "Bot: User data recognized"
    # now check what to do: join a current game or create a new one
    create_or_join_a_game
  end
  
  def create_or_join_a_game
    if @join_game and @game_to_join
      join_current_pg_game
    elsif @join_game
      @log.debug "No game to join - exit for me"
      exit
    else
      # create a new one
      create_new_pg_game
    end
  end
  
  def table_add_userdata(nick_name)
  end
  
  def table_remove_user(nick_name)
  end
  
  def pushfront_viewgames_data(data_table)
  end
  
  ##
  # Add a new game engine to the current bot.
  # Here we can support more than one engine per robot.
  # name: the key in the game yaml, e.g. :briscola_game
  def add_support_engine(name)
    @log.debug "Bot: add_support_engine#{name}"
    ini_size = @supported_games.size
    @all_games_bots.each do |item|
      if item[:key] == name
        @supported_games << item
      end
    end
    fin_size = @supported_games.size
    if fin_size <= ini_size
      @log.error "Bot: engine #{name} not supported"
    end
  end
  
  def registerTimeout(timeout, met_sym_tocall, met_notifier)
    met_notifier.send(met_sym_tocall)
  end
  
  ##
  # Select the current game engine for the incoming match
  def select_engine(name)
    @log.debug "Bot: select_engine #{name}"
    found = false
    @all_games_bots.each do |item|
      if item[:key] == name
        found = true
        @log.debug "Bot: Game Engine selected: #{name}, #{item[:core_name]}, #{item[:alg_name]}"
        @game_to_play = item
      end
    end
    unless found
      @log.error "Bot: ERROR Game Engine not found: #{name}\nExit for me"
      exit
    end
  end
  
  # chat methods
  def render_chat_tavolo(msg)
    str_def_risp = "Ciao, sono un robot di cuperativa.invido.it che gioca online. So giocare ma non chattare."
    if msg =~ /#{str_def_risp}/
    else
      @control_net_conn.send_chat_text(str_def_risp, :chat_tavolo)
    end
  end
  
  def render_chat_lobby(msg)
  end
  
  # settings
  
  ##
  # Load bot settings from yaml file
  def load_settings
    yamloptions = {}
    prop_options = {}
    #p @settings_filename
    yamloptions = YAML::load_file(@settings_filename) if File.exist?( @settings_filename )
    prop_options = yamloptions if yamloptions.class == Hash
    @settings_default.each do |k,v|
      if prop_options[k] != nil
        # use settings from yaml
        @app_settings[k] = prop_options[k]
      else
        # use default settings
        @app_settings[k] = v
      end
    end
    #p self.app_settings
    @playfor_classment = @app_settings[:playfor_classment]
    @login_name = @app_settings[:login]
    @server_ip = @app_settings[:server_ip]
    @server_port = @app_settings[:server_port]
    @password_login_md5 = Base64::encode64(@app_settings[:password])
    #select_engine(@app_settings[:engine])
    @supported_games = []
    supp_games =  @app_settings[:engine]
    supp_games.each{|e| add_support_engine(e)}
  end
  
  ##
  # Save bot settings to the yaml file. Develop purpose.
  def save_settings
    File.open( @settings_filename, 'w' ) do |out|
      YAML.dump( @app_settings, out )
    end
    @log.debug "Settings saved into #{@settings_filename}"
  end
  
  ##### Logger
  
  def log_sometext(str)
    @log.info(str)
  end
  
  def log_info(str)
    #t = Time.now.strftime("%d/%m/%Y %H:%M:%S")
    #@log.info("[#{t}]#{str}")
    @log.info(str)
  end
  
  #####
  
  def create_new_singlegame_window(type)
    return self
  end
  
end


if $0 == __FILE__
  begin
    puts "Starting the bot_player_creator"
    bot = CuperativaBot.new
    bot.settings_filename = File.join(File.dirname(__FILE__), 'bot_player_creator/robot.yaml')
    bot.log_debug
    bot.load_settings
    #bot.save_settings
    bot.run
    bot.join_run
    puts "Run thread terminated"
  rescue => detail
    p [:error, "#{$!}", detail.backtrace.join("\n")]
  end
  
end

# this part is now on the bot game
###################
## PART used when the robot is started using daemon
###################
  #bot = CuperativaBot.new
  #bot.log_production
  #bot.load_settings
  #trap(:INT){ 
    #bot.log_info( "robot shutdown");
    #bot.exit
  #}
  #bot.run
  #bot.join_run
################
##END
################  
  
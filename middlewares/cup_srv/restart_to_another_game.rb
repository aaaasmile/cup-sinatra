#file restart_to_another_game.rb


module MyGameServer
  include Log4r

  class RestartToAnotherGame
    include ProtBuildCmd
    
    def initialize(conn_players)
      @conn_players = conn_players
      @log = Log4r::Logger['coregame_log'] 
      @restart_state = :state_init
      @joined = {}
    end
    
    def event_raised(event, args)
      @log.debug "Raised event #{event} in state #{@restart_state}"
			p [:debug_another, args[:user_name], args[:info_detail]]
      case @restart_state
        # STATE: INIT
      when :state_init
        case event
        when :ev_restart_this_game
          state_restart_this_game
          @joined = {args[:user_name] => :ok}
          inform_player_about_restartthisgame(args[:user_name], args[:g_ix])
        when :ev_create_another
          state_another_created
          @creator_another_conn = args[:conn]
          send_rsa_response(args[:conn], :ok_create)
          create_challenge_info(args[:conn], args[:info_detail])
        end
        # STATE: ANOTHER_CREATED
      when :state_another_created
        case event
        when :ev_create_another
          send_rsa_response(args[:conn], :reject_create)
        when :ev_join
          @joined[args[:user_name]] = :ok
        when :ev_decline
          @joined[args[:user_name]] = :declined
        end
        # STATE: RESTART_THIS_GAME  
      when :state_restart_this_game
        case event
        when :ev_restart_this_game
          #p args
          @joined[args[:user_name]] = :ok
          #p @joined
          #
        end
      end
    end
    
    def state_restart_this_game
      @restart_state = :state_restart_this_game
      @log.debug "state changed to #{@restart_state}"
    end
    
    def state_another_created
      @restart_state = :state_another_created
      @log.debug "state changed to #{@restart_state}"
    end
    
    # BEGIN list of request handlers
    
    def create_req(conn, info_detail)
      event_raised(:ev_create_another, {:conn => conn, :info_detail => info_detail})
    end
    
    def decline_req(conn)
      event_raised(:ev_decline, {:conn => conn})
    end
    
    def join_req(conn)
      event_raised(:ev_join, {:conn => conn})
    end
    
    def restart_this_game_req(user_name, g_ix)
      event_raised(:ev_restart_this_game, {:user_name => user_name, :g_ix => g_ix})
    end
    
    
    #END Request handlers
    
    # state: :ok, :not_conf, :declined
    def get_num_of_join(state)
      count = 0
      @joined.each_value do |v|
        count += 1 if v == state
      end
      return count
    end
    
    def get_game_info
      return @current_game_info
    end
    
    def create_challenge_info(conn, game_info)
      @joined = {}
      @current_game_info = game_info
      @conn_players.each do |k, v|
        if k != conn.user_name
          @joined[k] = :not_conf
          send_rsa_challenge(v, game_info)
        else
          @joined[k] = :ok
        end
      end
    end
    
    def send_rsa_msg(conn, info_det)
      cmd = build_cmd(:restart_withanewgame, info_det)
      conn.send_data cmd
    end
    
    def send_rsa_response(conn, resp_detail)
      info_det = JSON.generate({ :type_req => :resp, :resp_code => resp_detail})
      send_rsa_msg(conn,info_det)
    end
    
    def send_rsa_challenge(conn, game_info)
      info_det = JSON.generate({ :type_req => :challenge, :detail => game_info})
      send_rsa_msg(conn,info_det)
    end
    
    def inform_player_about_restartthisgame(user_name, g_ix)
      str_det = "#{g_ix},#{user_name}"
      cmd = build_cmd(:restart_game_ntfy, str_det)
      @conn_players.each{|k, conn| conn.send_data cmd}
    end
    
    def is_game_ready_to_restart?
      count = 0
      @joined.each_value do |v|
        count += 1 if v == :ok
      end
      #p count
      #p @conn_players.values.size
      return count == @conn_players.values.size ?  true : false
    end
    
  end
  
end
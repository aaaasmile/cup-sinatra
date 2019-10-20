# file: pg_item.rb

module MyGameServer
  
	include Log4r

  ##
  # Class to handle a pending game item
  class PgItem
    attr_accessor :game, :options, :nal_server, :pin_originator, :scored_game
    attr_reader :creator_conn, :creator_score 
    
    # game : game name as string, e.g. 'Briscola'
    # options : core option game as hash, section :opt_game of pg_create2 message
    def initialize(game,options)
      # the creator of the pending game, game owner
      #@user_name = user
      # game name as string,
      @creator_conn = nil
      @game = game 
      @options = options
      # when a pg is created an acceptd, uses field below to manage the game
      # Interface adapter between server socket and core game  
      # Creato in pg_list e assegnato via accessor (vedi dir nal_games)
      @nal_server = nil
      # List of all players that have joined the game, array of user names
      @players = {}
      # tender element. It is an user_name that wait a confirm from game owner 
      # to join the game
      @tender = {}
      # pin private, when the game is crated
      @pin_originator = nil
      # pin private, when the game is joined
      @pin_given = {}
      # Ranking type game
      @scored_game = true
      # gender of creator
      @creator_gender = ''
      # ranking current score of the creator
      @creator_score = 0
      # user type that create the game (:user, :computer, :female)
      @creator_user_type = :user
      # logger
      @log = Log4r::Logger["serv_main"]  
    end
    
    ##
    # Check if the current item is valid
    def is_valid?
      return  true if PendingGameList.is_game_valid?(@game)
      @log.error "ERR: Invalid game item #{@game}" 
      return false
    end
    
    def add_creator_info(conn, user_name, creator_gender, creator_score)
      @creator_conn = conn
      @creator_user_name = user_name
      @creator_gender = creator_gender
      @creator_score = creator_score
      @creator_user_type = :user
      if @creator_gender == "F"
        @creator_user_type = :female
      elsif @creator_gender == "C"
        @creator_user_type = :computer
      end
      add_player(conn)
    end
    
    def get_creator_name
      return @creator_user_name
    end
    
    def is_join_req_part1_ok?(conn)
      # check if the user is joining a self created game
      if @creator_user_name == conn.user_name
        # error, joint to self created game
        @log.debug "Join a self created game is not possible"
        return 2
      end
      
      # check if join a private game
      if @nal_server.is_privategame?
        # private game has a pin
        if is_pin_privategame_false?(conn.user_name)
          @log.debug "Pin of tender #{conn.user_name} is not ok"
          return 3
        end
      end
      
      # check if the player is a guest and try to join a ranking game
      if conn.is_guest? and @scored_game
        @log.debug "Connection guest try to tender ranking game"
        return 4
      end
      
      return 0
      
    end
    
    def is_joinok_ok?(conn_creator, conn_tender)
      if @creator_conn == nil
        @log.debug "@creator_conn is nil"
        return 11
      end
      if conn_tender == nil
        @log.debug "conn_tender is nil"
        return 12
      end
      unless @creator_user_name != conn_tender.user_name
        # only creator can confirm tender
        @log.debug "Game created by #{@creator_user_name} but confirmed by #{conn_tender.user_name}"
        return 8
      end
      # send response to the tender
      unless @tender[conn_tender.user_name]
        @log.debug "No tender #{conn_tender.user_name} is available anymore" 
        return 9
      end
      return 0
    end
    
    def get_creatorusertype
      #p @creator_gender
      return @creator_user_type
    end
    
    ##
    # Provides the player list field
    def get_str_playerlist
      str = @players.join(",")
      return "{#{str}}"
    end
    
    ##
    # Add player to the pg
    def add_player(conn)
      if conn
        @players[conn.user_name] = conn
      end
    end
    
    def get_players_connected
      return @players
    end
    
    ##
    # Check if the give pin code for the private game is false
    # Return true if the pin for private game is not right
    def is_pin_privategame_false?(user_name)
      pin_given = @pin_given[user_name]
      if @pin_originator != pin_given
        return true
      end
      return false 
    end
    
    def set_pin_given(user_name, pin)
      @pin_given[user_name] = pin
    end
    
    ##
    # Provides true if the game is valid for ranking
    def is_scored_game?
      return @scored_game
    end
    
    def is_tender_submitted?(user_name)
      return @tender[user_name] != nil ? true : false
    end
    
    def is_possible_to_tender?()
      num_of_tenders = (@nal_server.get_numofplayer_tostart - 1) # creator is not a tender
      @log.debug "Tendering with #{@tender.keys.size} on #{num_of_tenders}"
      return @tender.keys.size < num_of_tenders  ? true : false
    end
    
    def add_tender(conn)
      @tender[conn.user_name] = conn
    end
    
    def is_conn_creator_available? 
      return @creator_conn != nil ? true : false
    end
    
    def remove_user(user_name)
      if user_name == @creator_user_name 
        @creator_conn = nil
      end
      @tender.delete(user_name) 
      @players.delete(user_name)
    end
    
    ##
    # Provides true if the game is private (pin was set)
    def is_private?
      return @pin_originator == nil ? false : true
    end
    
    ##
    # Provides list of players in the game
    def get_players_username_list
      return @players.keys
    end
    
    ##
    # Provides the number of current players on the pg game
    def get_num_of_players
      return @players.keys.size
    end
    
  end #end PgItem
  
end
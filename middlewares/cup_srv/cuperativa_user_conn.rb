# file: cuperativa_user_conn.rb
# on windows work only with ruby 1.85 and binarygem

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'base64'
require 'network/prot_parsmsg'
require 'network/prot_buildcmd'
require 'mod_user_conn_handl'
require 'database/sendemail_errors'
require 'base/core/cup_strings'
require 'json'

module MyGameServer
  
$conn_counter = 0

##
# class CuperativaUserConn
# Instance for each player, because each connection is associated to one player
class CuperativaUserConn
  attr_reader :user_name, :user_id
  attr_accessor :game_in_pro, :user_lag, :user_type, :user_stat
  
  
  # defualt command handler  
  include ParserCmdDef 
  include ProtBuildCmd
  
  def initialize(ws)
    begin
      @log = Log4r::Logger['serv_main']
      @socket_verbose_debug = false # set to true to see every read and write socket details
      @ws_socket = ws
      post_init
    rescue => detail
      @log.error "initialize error(#{$!})"
      error(detail)
    end
  end

  # # part adapted from protocol LineText2 - start
  # MaxLineLength = 16*1024
  # MaxBinaryLength = 32*1024*1024
  
  def is_guest?
    return @is_guest
  end
  
  ##
  # Client is accepted, init stuff
  def post_init
    @user_id = nil # user id stored in db
    @is_guest = false
    @ping_request = false
    @start_time = Time.now
    @user_name = ""
    @state_con = :created
    # TODO:  remove dependency from @main_my_srv 
    @main_my_srv = CuperativaServer.instance
    @conh_settings =  @main_my_srv.serv_settings[:connhandler_opt]
    @version_to_package = @conh_settings[:version_to_package]
    # send server version
    send_data( build_cmd(:ver, "#{VER_MAJ}.#{VER_MIN}" ))
    # send welcome message
    send_data( build_cmd(:info, "WELCOME_SERVER_CUPERATIVA_WS - (#{PRG_VERSION}) " ))
    @main_my_srv.add_conn(self)
    #log "Player online #{@clients.size}" 
  
    # game in progress
    @game_in_pro = nil
    # user lag (1 = poor, 5 good)
    @user_lag = 5 
    # user type (G)uest, (P)layer registered, (A)dmin
    @user_type = 'G' 
    # user info (staistic, status.....)
    @user_stat = '-'

    @use_rec_thread = false
    if @use_rec_thread
      @rd_stop_thread = false
      @recv_queue = []
      @mutex_recv = Mutex.new
      @rd_sock_thread = Thread.new{ background_proc_rec }
    end
  end 
    
  ##
  # State leaved info
  def has_leaved?
    @state_con == :logged_out ? true : false
  end

  ##
  # Line is received
  def receive_line(line)
    #line = line_array.pack('C*')
    @ping_request = false # client is alive
    pl_message = line
    arr_cmd_msg = pl_message.split(":")
    unless arr_cmd_msg
      @log.warn "receives a malformed line error (#{line})"
      return
    end
    p line
    if arr_cmd_msg.first == 'LOGIN'
      @log.debug "command is #{arr_cmd_msg.first} ..."
    else
      @log.debug "Line is #{line}"
    end
    cmd = arr_cmd_msg.first
    cmd_details = ''
    # details of command
    if arr_cmd_msg[1..-1]
      cmd_details = arr_cmd_msg[1..-1].join(":")
    end
    #retreive the symbol of the command handler
    meth_parsed = nil 
    ProtCommandConstants::SUPP_COMMANDS.each do |k,v| 
      meth_parsed = v[:cmdh] if v[:liter] == cmd 
    end
    # call the command handler
    if meth_parsed != :cmdh_login && meth_parsed != :cmdh_user_exist && meth_parsed != :cmdh_user_op &&
       @state_con != :logged_in
      # player not logged in, ignore message
      p meth_parsed
      @log.warn "[#{@user_name}]: not logged in, ignore msg \"#{pl_message}\""
    else
      if meth_parsed
        # method accepted, because player is already logged in
        p [:read, meth_parsed, cmd_details] if @socket_verbose_debug
        if @use_rec_thread
          push_det = {:meth => meth_parsed, :det => cmd_details }
          
          @mutex_recv.synchronize{
            @recv_queue.insert(0, push_det)
          }
        else
          send meth_parsed, cmd_details
          p [:parser_completed, meth_parsed] if @socket_verbose_debug
        end
      else
        @log.error("Line recived is not recognized and ignored #{line}")
      end
    end
  rescue => detail
    @log.error "receive_line error(#{$!})"
    error(detail)
		close_connection('Client message error, bye client')
  end

  def background_proc_rec
    while !@rd_stop_thread
      msg = nil
      @mutex_recv.synchronize{
        msg = @recv_queue.pop
      }
      if msg != nil
        @log.debug "[QRECPROC]: #{msg[:det]}, #{msg[:meth]}"
        send msg[:meth], msg[:det]
      end
      sleep 0.2
    end
  end
  
  ##
  # Closing connection notification
  def unbind
    #elapsed = (Time.now - @start_time).strftime("%H:%M:%S") # questo NON VA
    elapsed = (Time.now - @start_time)

    if @game_in_pro
      @log.warn "Player #{@user_name} disconnect a game in progress without leaving table"
      @main_my_srv.game_inprog_player_disconnect(@user_name, @game_in_pro.ix_game, @game_in_pro, :player_accident_disconnect)
      #@main_my_srv.game_inprog_playerleave(@user_name, @game_in_pro.ix_game, @game_in_pro)
    end
    
    @main_my_srv.remove_connection(self)
    if @rd_sock_thread
      @rd_stop_thread = true
      @rd_sock_thread.join
    end
    @log.info("#{@user_name} Connection closed, time connected: #{elapsed}")
  end
  
  def send_ping()
    @ping_request = true
    cmd_ping = build_cmd(:ping_req, "")
    send_data(cmd_ping)
  end
  
  ##
  # Provides the status of a ping request. Request is turned off when data
  # are received
  def ping_is_pending?
    return @ping_request
  end
  
  ##
  # log
  def log(str)
    @log.info(str)
  end
  
  def log_debug(str)
    @log.debug(str)
  end
  
  ##
  # Log chat message in the current table log channel
  def log_table(str)
    @game_in_pro.nal_server.log_table_comm(str) if @game_in_pro
  end
  
  def error(details)
    @log.error("ERROR connection:")
    @log.error(details.backtrace.join("\n"))
    # send also an email for this kind of errors
    #sender = EmailErrorSender.new(@log)
    #sender.send_email("#{$!}\n" + detail.backtrace.join("\n"))
  end
  
  ##
  # default logger for prot_parmsg.rb
  def log_sometext(str)
    log str
  end
  
  def send_data(data)
		return if @ws_socket == nil
    #payload = data.chomp.unpack('C*')
    payload = JSON.generate(data.chomp)
    p [:ws_send, @ws_socket.object_id, payload] if @socket_verbose_debug
    @ws_socket.send(payload)
  end

  def close_connection(reason)
    if @ws_socket == nil
      @closing = false
      return
    end
    if @closing
      return 
    else
      @closing = true
      sleep 1
    end

    unless @ws_socket.nil?
			@log.debug "Close socket #{reason}"
      @ws_socket.close
      @ws_socket = nil
      @closing = false
    end
  end

  def close_connection_after_writing(reason)
    @closing = true
    sleep 1
    close_connection(reason)
  end
  
  #
  # COMMAND HANDLER
  #
   
  include UserConnCmdHanler
    
end #end CuperativaUserConn

end #module
require 'faye/websocket'
require 'permessage_deflate'
require './middlewares/cup_srv/cuperativa_server'
require './middlewares/cup_srv/cuperativa_user_conn'
require 'log4r'

include Log4r

module CupSinatra
  include Log4r
  class CupBackend
    KEEPALIVE_TIME = 15 # in seconds
    
    def initialize(app)
      @app = app
      @clients = {}
      @log = Log4r::Logger.new("CupBackend")
      Log4r::Logger['CupBackend'].outputters << Outputter.stdout
      @main_my_srv = MyGameServer::CuperativaServer.instance
      @timer_thread = nil
    end

    def call(env)
      # process request
      if Faye::WebSocket.websocket?(env)
        begin 
          @log.debug "Websocket bind request #{env['HTTP_HOST']}, #{env['PATH_INFO']}"
          options = {:extensions => [], :ping => 20}
          ws = Faye::WebSocket.new(env, [], options)
          p [:socket, ws.ping]
          unless @timer_thread
            @main_my_srv.connect_to_db
            @log.debug "Start periodic timer - game processing -"
            @timer_thread = Thread.new {
              while true
                begin
                  @main_my_srv.process_game_in_progress
                  sleep 0.05
                rescue => detail
                  @log.error "Error with process_game_in_progress timer: #{$!}"
                  @main_my_srv.error(detail)
                  exit
                end
              end
            }
          end
        rescue => detail
          @log.error "error #{$!}"
          @log.error detail.backtrace.join("\n")
        end

        ws.on :open do |event|
          begin
            @log.debug "Websocket connected with #{[:open, ws.object_id]}"
            @clients[ws.object_id] = MyGameServer::CuperativaUserConn.new(ws)
          rescue => detail
            @log.error "error #{$!}"
            @log.error detail.backtrace.join("\n")
          end
        end

        ws.on :error do |event|
          p [:error, event.message]
        end

        ws.on :message do |event|
          begin
            #p [:message, event.data]
            if event.data != "\x8A\x00" # pong is ignored
              #puts "Message received #{event.data}"
              #@clients[ws.object_id].receive_line(Base64::decode64(event.data))
              @clients[ws.object_id].receive_line(event.data)
              #p payload = sanitize(event.data)
            end
          rescue => detail
            @log.error "error #{$!}"
            @log.error detail.backtrace.join("\n")
          end
        end

        ws.on :close do |event|
          begin
            @log.debug  "Websocket closed notification for #{ws.object_id}"
            p [:close, ws.object_id, event.code, event.reason]
            if @clients[ws.object_id] 
              @clients[ws.object_id].unbind
              @clients[ws.object_id] = nil
            end
            ws = nil
          rescue => detail
            @log.error "error #{$!}"
            @log.error detail.backtrace.join("\n")
          end
        end

        # Return async Rack response
        ws.rack_response
      else
        @app.call(env) # usual sinatra http process request
      end
    end

    private
    def sanitize(message)
      return ERB::Util.html_escape(message)
    end
  end
end

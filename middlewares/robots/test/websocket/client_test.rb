require 'rubygems'

require 'websocket'
require 'socket'
require 'thread'
require 'log4r'

include Log4r

class ClientWs
  def initialize
    @log = Log4r::Logger.new("client_ws") 
    @log.outputters << Outputter.stdout
    @server_msg_aredebugged = true
  end

  def run
    url = 'ws://localhost:3000/websocket'
    @log.debug "Runt to #{url}"
    @socket_srv = TCPSocket.new('localhost', 3000)
    @handshake = WebSocket::Handshake::Client.new(url: url, 
      headers: {'Sec-WebSocket-Protocol' => 'chat, superchat' })

    @log.debug "send handshake: #{@handshake.to_s}"
    @handshake_is_finalized = false
    @socket_srv.puts @handshake.to_s

    @rd_sock_thread = Thread.new{ background_read }

    sleep 1
    @log.debug "Send a frame"
    frame = WebSocket::Frame::Outgoing::Client.new(version: @handshake.version, data: "LOGIN:igor", type: :text)
    #@socket_srv.send frame.to_s, 0   #"LOGIN:igor"
    @socket_srv.puts frame.to_s
    p frame.to_s
  end

  def join_run
    @rd_sock_thread.join
  end

  ##
  # Background read, thread handler
  def background_read
    @log.debug "Background read start"
    begin
      while true
        dat = @socket_srv.gets
        if dat.nil?
          @log.debug "data nil, terminate read"
          break
        elsif dat.empty?
          @log.debug "data empty, try to continue"
          next
        end 
        p dat 
        #@log.debug "<server> #{dat.chomp}" if @server_msg_aredebugged
        if !@handshake.finished? && !@handshake_is_finalized
          @handshake << dat
        elsif !@handshake_is_finalized
          @log.debug "Handshake is finalized, valid: #{@handshake.valid?}"
          @handshake_is_finalized = true
        end
      end
    rescue
      @log.warn "socket read end: (#{$!})"
    ensure
      @log.debug "Background read terminated"
      @socket_srv = nil
    end
  end 

end #end ClientWs


if $0 == __FILE__
  puts 'Web socket test'
  client = ClientWs.new
  client.run
  client.join_run
end
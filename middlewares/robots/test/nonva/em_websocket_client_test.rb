require 'em-websocket-client'

# provato con ruby 2.2.4, solita perdita di tempo sotto windows


class Connector
  def connect
    EM.run do
      conn = EventMachine::WebSocketClient.connect("ws://localhost:3000/websocket")

      conn.callback do
        conn.send_msg "Hello!"
        conn.send_msg "done"
      end

      conn.errback do |e|
        puts "Got error: #{e}"
      end

      conn.stream do |msg|
        puts "<#{msg}>"
        if msg.data == "done"
          conn.close_connection
        end
      end

      conn.disconnect do
        puts "gone"
        EM::stop_event_loop
      end
      loop do
        conn.send STDIN.gets.strip
      end
    end
    
  end
  
end

if $0 == __FILE__
  ct = Connector.new
  ct.connect
end
require 'websocket-eventmachine-client'

# Non va sotto windows... (provato con ruby 2.3.1)

EM.epoll
EM.run do

  trap("TERM") { stop }
  trap("INT")  { stop }

  ws = WebSocket::EventMachine::Client.connect(:uri => "ws://localhost:3000/websocket");

  ws.onopen do
    puts "Connected"
    ws.send "Hello"
  end

  ws.onmessage do |msg, type|
    puts "Received message: #{msg}"
    ws.send msg, :type => type
  end

  ws.onclose do
    puts "Disconnected"
  end

  ws.onerror do |e|
    puts "Error: #{e}"
  end

  ws.onping do |msg|
    puts "Receied ping: #{msg}"
  end

  ws.onpong do |msg|
    puts "Received pong: #{msg}"
  end

  def stop
    puts "Terminating connection"
    EventMachine.stop
  end

end
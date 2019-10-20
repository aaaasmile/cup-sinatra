require 'rubygems'
require 'websocket-client-simple'

# it works only if ws is not a member class

ws = WebSocket::Client::Simple.connect 'ws://localhost:3000/websocket'
#ws = WebSocket::Client::Simple.connect 'wss://cuperativa-2016.herokuapp.com/websocket'

ws.on :message do |msg|
  puts msg.data
end

ws.on :open do
  puts 'Socket is now open'
  ws.send 'LOGIN:igor'
end

ws.on :close do |e|
  p e
  exit 1
end

ws.on :error do |e|
  p e
end

loop do
  ws.send STDIN.gets.strip
end
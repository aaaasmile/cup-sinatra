require 'socket'


port = 3002
ARGV.each do|a|
  puts "Argument port: #{a}"
  port = a.to_i
  break
end
s = TCPSocket.new 'localhost', port

puts "Connecting with the bot (port #{port}) and requst to resend the last packet"
while line = s.gets # Read lines from socket
  puts line         # and print them
end

s.close             # close socket when done
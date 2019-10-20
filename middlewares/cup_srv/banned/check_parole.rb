require 'base64'

arr = []
File.open("parolacce.txt").each_line do |line|
  #str =  line.chomp
  str = Base64::encode64(line.chomp)
  arr << str
end
p arr

arr.each{|e| p Base64::decode64(e)}
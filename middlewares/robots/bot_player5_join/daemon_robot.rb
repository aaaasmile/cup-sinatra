#file: daemon_robot.rb
# usage: ruby daemon_robot.rb start  
#        ruby daemon_robot.rb stop
# ache il comando run funziona



require 'rubygems'
require 'daemons'

script_fname = File.expand_path( File.dirname(__FILE__) + '/bot_start.rb') 
Daemons.run(script_fname)
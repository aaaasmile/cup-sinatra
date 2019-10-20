#file: bot_start.rb

$:.unshift File.dirname(__FILE__)
$:.unshift(File.expand_path( File.join(File.dirname(__FILE__), '..')))
$:.unshift(File.expand_path( File.join(File.dirname(__FILE__), '../..')))

require 'cuperativa_bot'

###############
# Code executed when the daemon is started

  bot = CuperativaBot.new
  bot.settings_filename = File.join(File.dirname(__FILE__), 'robot.yaml')
  bot.log_debug
  bot.load_settings
  bot.run
  bot.join_run
###############
#END
############### 


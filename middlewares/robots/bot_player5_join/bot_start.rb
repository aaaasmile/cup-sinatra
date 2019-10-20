#file: bot_start.rb

$:.unshift File.dirname(__FILE__)
$:.unshift(File.expand_path( File.join(File.dirname(__FILE__), '..')))
$:.unshift(File.expand_path( File.join(File.dirname(__FILE__), '../..')))

require 'cuperativa_bot'

###############
# Code executed when daemon is started

  bot = CuperativaBot.new
  bot.settings_filename = File.join(File.dirname(__FILE__), 'robot.yaml')
  bot.log_production
  bot.load_settings
  trap(:INT){ 
    bot.log_info( "robot shutdown - exit ");
    bot.exit
  }
  bot.run
  bot.join_run
###############
#END
############### 


# file: test_common.rb
# common stuff for test core

PATH_TO_SERVER = File.expand_path(File.dirname(__FILE__) + '/..')
#PATH_TO_CLIENT = File.expand_path(File.dirname(__FILE__) + '/../../src')
#require File.join( PATH_TO_SERVER, 'cup_serv_core')
require File.join( PATH_TO_SERVER, 'mod_user_conn_handl')
require File.join( PATH_TO_SERVER, 'network/prot_parsmsg')
require File.join( PATH_TO_SERVER, 'network/prot_buildcmd')

#
# Class used to intercept log to recognize errors and warning
class FakeIO < IO
  attr_accessor :warn_count, :error_count
  
  def initialize(arg1,arg2)
    super(arg1,arg2)
    reset_counts
    @cards_played = []
  end
  
  def reset_counts
    @warn_count = 0; @error_count = 0;
  end
  
  def print(*args)
    #print(args)
    str = args.slice!(0)
    aa = str.split(':')
    if aa[0] =~ /WARN/
      @warn_count += 1
    elsif aa[0] =~ /ERROR/
      @error_count += 1
    end
    # check something like "Card _2c played from player Gino B.\n"
    if aa[1].strip =~ /Card (_..) played from player (.*)/
      card_lbl = $1
      name_pl = $2
      @cards_played << {:card_s => card_lbl, :name => name_pl }
    end
  end
  
  ##
  # Check if a card was played because trace info.
  # provides position if played card is found
  # name: player name (e.g. "Gino B.")
  # card_lbl: card label to find (e.g "_2c")
  def check_playedcard(name, card_lbl)
    pos = 0
    #p @cards_played
    @cards_played.each do |cd_played_info|
      if cd_played_info[:name] == name and card_lbl.to_s == cd_played_info[:card_s]
        return pos
      end
      pos += 1
    end
    return nil
  end
  
end

############################################################################
############################################################################
########################################################    FakeUserConn

##
# Class used to proxy the class CuperativaUserConn
class FakeUserConn
  attr_accessor :user_name,:is_guest, :user_passw, :game_in_pro, :last_data_sent, :data_sent
  
  include ParserCmdDef
  include ProtBuildCmd
  include UserConnCmdHanler
   
  
  def initialize
    @user_name = "Tontouser"
    @user_passw = ''
    @data_sent = []
    @log = Log4r::Logger['serv_main']
    @game_in_pro = nil
    @main_my_srv = nil
    @last_data_sent = ''
    @is_guest = false
  end
  
  def is_guest?
    return @is_guest
  end
  
  def init_core_server
    @main_my_srv = MyGameServer::CuperativaServer.instance
  end
  
  def send_data(data)
    puts "send_data to #{user_name} (next line):"
    puts data
    @data_sent << data
    @last_data_sent = data
  end
end
  
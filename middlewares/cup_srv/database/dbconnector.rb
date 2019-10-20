#file: dbconnector.rb
#file used to establish the connection with the database

$:.unshift File.dirname(__FILE__)

require 'rubygems'
require 'cup_classifica'
require 'cup_user'
require 'pg'
require 'yaml'
require 'log4r'
require 'captcha_validator'

include Log4r
#require 'benchmark'

#include Benchmark

module MyGameServer

  class BasicDbConnector
    attr_reader :db_connector

    def initialize
      @log = Log4r::Logger["DbConnector"]
      fname = (ENV['RACK_ENV'] != 'production') ? 'options.yaml' : 'options-production.yaml'
      @settings_filename = File.join(File.dirname(__FILE__), "../#{fname}")
      load_settings
      connect_to_db(@options[:database][:user_db],
                                 @options[:database][:pasw_db],
                                 @options[:database][:db_name],
                                 @options[:database][:host],
                                 @options[:database][:port],
                                 @options[:secret_server]) 
    end
  
    def load_settings
      @log.debug "Loading DB settings from #{@settings_filename}"
      @options = YAML::load_file(@settings_filename)
    end
  
    def connect_to_db(user_db, password_db, name_db, host, port, authkey)
      # database connector
      CupDbDataModel::CupBasicDbModel.use_debug_sql = @options[:database][:debug_sql]
      @db_connector = MyGameServer::DbDataConn.new(@log, user_db, password_db, name_db, host, port, authkey)
      @db_connector.connect
      captcha_validator = CaptchaValidator.new(@options[:secret_captcha])
      @db_connector.captcha_validator = captcha_validator
    end
  end  

###############################################################################################################
##
# Class used to communicate with the database
class DbDataConn
  attr_reader :active_pg_conn
  attr_accessor :captcha_validator

  def initialize(log, user, password, name_db, host, port, authkey)
    @log = log
    @user = user
    @password = password
    @database_name = name_db
    @host = host
    @port = port
    @active_pg_conn = nil
    @authkey = authkey
  end
  
  def connect
    connect_pg
  end

  def connect_pg
    @active_pg_conn = PG::Connection.open(:dbname => @database_name, :user => @user, :password => @password, :host => @host, :port => @port)
    @log.debug "Connected to the database #{@database_name} using user: #{@user} and password: xxxx, host: #{@host}, port: #{@port}"
  end

  def get_user_by_auth(login, password, token)
    @log.debug "Checking credential for #{login}"
    res = try_to_authenticate(login, password, token)
    if res.nil?
      @log.debug "retry check in db"
      res = try_to_authenticate(login, password, token)
    end
    return res
  end
  
  def try_to_authenticate(login, password, token)
    begin
        user = CupDbDataModel::CupUser.authenticate(login, password, token, @authkey, @active_pg_conn)
        if user
          user.lastlogin = Time.now
          if (user.remember_token == nil) || (Time.now > user.remember_token_expires_at)
            user.create_remember_token
          end
          user.save(@active_pg_conn)
          return user
        end
        #return user ? true : false
        return nil
    rescue => detail
      # error, try to connect
      @log.error "authenticate is failed with error #{$!}"
      @log.error detail.backtrace.join("\n")
      connect
      return nil
    end
  end
  
  ##
  # Find user using the login
  def finduser(username)
    begin
      user = CupDbDataModel::CupUser.find_by_login(username, @active_pg_conn)
      return user
    rescue => detail
      @log.error "finduser is failed with error #{$!}"
      @log.error detail.backtrace.join("\n")
      connect
      return nil
    end
  end

  ##
  # Find or create an item in the ranking table
  # game_name : string sent in pg_create2 as gioco_name field
  # user_id: 
  def find_or_create_classifica(game_name, user_id)
    type = CupDbDataModel::CupClassifica.type_current
    class_item = CupDbDataModel::CupClassifica.find_by_user_id(game_name, user_id, type, @active_pg_conn)
    unless class_item
      # create a new item 
      @log.debug "Create a new classifica #{game_name} for user #{user_id}"
      class_item = CupDbDataModel::CupClassifica.new
      class_item.name = game_name
      class_item.user_id = user_id
      class_item.type = type
      class_item.save(@active_pg_conn)
    end
    return  class_item
  end
    
  def create_user(opt)
    if (opt[:login] == nil) || (opt[:password] == nil) || (opt[:password].length < 6 || opt[:login].length < 5 )
      p opt
      raise "Wrong Login or password"
    end
    olduser =  CupDbDataModel::CupUser.find_by_login(opt[:login],@active_pg_conn)
    if olduser
      raise "User #{opt[:login]} already in the db"
    end
    validate_captcha(opt[:token_captcha])
    
    @log.debug "Creating user #{opt[:login]}"
    newuser = CupDbDataModel::CupUser.new
    newuser.set_auth_key(@authkey)
    newuser.login = opt[:login]
    newuser.crypted_password = newuser.encrypt(opt[:password])
    newuser.state = opt[:state]
    newuser.email = opt[:email]
    newuser.deck_name = opt[:deck_name]
    newuser.gender = opt[:gender]
    newuser.fullname = opt[:fullname]
    newuser.save(@active_pg_conn)
    @log.debug "User  #{opt[:login]} in state #{opt[:state]} created"
    my_user =  CupDbDataModel::CupUser.find_by_login(opt[:login],@active_pg_conn)
    return my_user.id
  end

  def validate_captcha(token)
    @log.debug "Validate captcha token #{token}"
    success = @captcha_validator.validate(token)
    unless success
      raise "Captcha token validation error #{@captcha_validator.last_error}"
    end
  end

  def user_exist?(loginname)
    return false if (loginname == nil) || (loginname.length < 5)
    user =  CupDbDataModel::CupUser.find_by_login(loginname, @active_pg_conn)
    return user != nil
  end

  def remove_user(login)
    user =  CupDbDataModel::CupUser.find_by_login(login,@active_pg_conn)
    if user
      user.delete(@active_pg_conn)
      @log.debug "User #{login} successfully deleted"
    else
      @log.warn "User #{login} not found"
    end
  end
  
  # test stuff 
  def simple_test_pg
    @log.debug '---' + 
      RUBY_DESCRIPTION +
      PG.version_string( true ) +
      "Server version: #{@active_pg_conn.server_version}" +
      "Client version: #{PG.respond_to?( :library_version ) ? PG.library_version : 'unknown'}" +
      '---'
    
    result = @active_pg_conn.exec( "SELECT * from users" )
    
    @log.debug %Q{Expected this to return: ["select * from users"]}
    @log.debug result.field_values( 'login' )
    #p result[0] 
    p result[0]["login"],result[0]["crypted_password"],result[0]["email"]
  end
  
  def test_encry(login_name,password)
    user =  CupDbDataModel::CupUser.find_by_login(login_name, @active_pg_conn)
    return @log.debug "User #{login_name} not found" if !user

    user.set_auth_key(@authkey)
    p encr = user.encrypt(password)
    p stored_enc = user.fields["crypted_password"]
    @log.debug "test_encry on #{login_name}: " + encr + " Email: #{user.fields["email"]}" + " Password-db: #{stored_enc}" 
    @log.debug "Same? #{stored_enc == encr}"
  end
  
end

end #module


if $0 == __FILE__
  require 'rubygems'
  require 'log4r'
  include Log4r
  
  Log4r::Logger.new("DbConnector")
  Log4r::Logger['DbConnector'].outputters << Outputter.stdout
  log = Log4r::Logger['DbConnector']
  
  basic_conn = MyGameServer::BasicDbConnector.new
  ctrl = basic_conn.db_connector
  
  ctrl.validate_captcha('03ANcjosoR-e7HJNWNWwYa2y5yfNYx8W-aCnw5s50GxbXcjJUubN9cCmcoPSWPorJtvUcE7qrMLhO_bjYZLuxN9ZF5ZqL5I26GT1ACwoKexggI_kfQfZZ_zvTX3GvYVf1ZgSZ5-yR1wdR8hJkIlsR-ABinE_gJyIyFQGMU0fdgBgxpT6FFO5U28YAUBp320-pRriA1h_Z6yEpJYWNrE_JgjMbUS2-VdhZ_Wv-BrjvTy0CAGCHwDYg7tfmyteTf0cGENcznMObkOK3Me_w_57pva2O9gejpbUgDpaNixmXySLgMUQHuEqHvWrdON-87yVyW6oaUAQwn4uUbFVusRXznSyihZyIbArBB5pBGpAymTErNYnBfokVgOD6UV0hOqDlUxTGo1fTjR0XGslzqUEp-bHrnjQrKovYJA4LOO7o3JuoW6dJDoXTGpbrg12rjHEnYWF4ejuEBQZMrxNabtGPs59mcZDMC6yaYFH1g1iFPdxNLq-U3YhShIrpY-1Etsv4KjiolkQR2ZXPFeZvM-Y5Z4MBe2JBAfAKFow')

end
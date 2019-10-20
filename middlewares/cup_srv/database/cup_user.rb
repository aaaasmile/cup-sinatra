# file: cup_user.rb
require 'rubygems'
require 'dbcup_datamodel'

module CupDbDataModel

  ###########  CupUser #############################
  class CupUser < CupBasicDbModel
    attr_reader :fields
    attr_reader :roles
    # The @rest_auth_key  must be the same as in config/initializers/site_keys.rb
    # otherwise passwords check always fails. Here the key is read from server options.yaml
    REST_AUTH_DIGEST_STRETCHES = 10
    
    def initialize(fields={})
      super(fields,{:table_name => 'users',
                    :field_list => [:id,:lastlogin,:login,:state,:email,:crypted_password,:salt,:fullname,
                                    :gender,:remember_token,:remember_token_expires_at,:activated_at,:deleted_at,:last_seen_at,:newsletter_abo,:deck_name],
                    :fieldtypes => {:lastlogin => :datetime, :remember_token_expires_at => :datetime,
                                    :activated_at => :datetime, :deleted_at => :datetime, :last_seen_at => :datetime, :newsletter_abo => :boolean}
      })   
      @roles = []
      @rest_auth_key = ''
    end

    def self.get_model_name
      'CupUser'
    end

    def set_auth_key(k)
      @rest_auth_key = k 
    end

    def secure_digest(*args)
      digest_str = args.flatten.join('--')
      #p digest_str
      Digest::SHA1.hexdigest(digest_str)
    end
    
    def password_digest(password, salt)
      digest = @rest_auth_key
      # p salt, here salt is nil
      REST_AUTH_DIGEST_STRETCHES.times do
        digest = secure_digest(digest, salt, password, @rest_auth_key)
      end
      digest
    end
      
    def encrypt(password)
      self.salt = self.make_token if is_newrecord?
      password_digest(password, @salt)
    end

    def create_remember_token
      self.remember_token = self.make_token
      n_days = 1
      self.remember_token_expires_at = Time.now + n_days * 86400 # 24 * 60 * 60 
    end
    
    def authenticated?(password, token)
      if password != ''
        @crypted_password == encrypt(password)
      elsif Time.now < @remember_token_expires_at
        @remember_token == token
      end
    end
    
    def fillout_roles(dbpg_conn)
      @log.debug "Fillout roles"
      query = "SELECT role_code FROM user_in_role WHERE user_id = #{@id}"
      @log.debug query if @use_debug_sql
      result = dbpg_conn.async_exec( query )
      @roles = []
      result.each do |item|
        #p item # hash key => value as strings
        @roles << item['role_code'].strip
      end
    end
    
    def self.authenticate(login, password, token, auth_key, dbpg_conn)
      return nil if (login == '' || (token == '' && password == ''))
      #u = find :first, :conditions => {:login => login, :state => 'active'} # need to get the salt
      query = "SELECT * from users WHERE login='#{dbpg_conn.escape_string(login)}' AND state ='active'"
      cup_user = self.exec_sql_query_first(query, dbpg_conn)
      if cup_user
        cup_user.set_auth_key(auth_key)
        cup_user = cup_user.authenticated?(password, token) ? cup_user : nil
        cup_user.fillout_roles(dbpg_conn)
      end
      return cup_user
    end

    def self.find_by_login(login, dbpg_conn)
      return nil if (login == '' || login == nil)
      query = "SELECT * from users WHERE login='#{dbpg_conn.escape_string(login)}'"
      return self.exec_sql_query_first(query, dbpg_conn)
    end

    def self.find_by_id(user_id, dbpg_conn)
      return nil if (user_id == '' || user_id == nil)
      query = "SELECT * from users WHERE id='#{dbpg_conn.escape_string(user_id)}'"
      return self.exec_sql_query_first(query, dbpg_conn)
    end

    def self.is_admin(user_id, dbpg_conn)
      return false if (user_id == '' || user_id == nil)
      query = "SELECT COUNT(*) from user_in_role WHERE role_code='ADMIN' AND user_id='#{dbpg_conn.escape_string(user_id)}'"
      qres =  self.exec_sql_query(query, dbpg_conn)
      return qres.size == 1 && qres[0] == "1"
    end
  end #end users
end

if $0 == __FILE__
  require 'rubygems'
  require 'log4r'
  include Log4r
  
  Log4r::Logger.new("myuserctrl").outputters << Outputter.stdout
  log = Log4r::Logger["myuserctrl"]
  
  cup_user = CupDbDataModel::CupUser.new
  enc = cup_user.encrypt('123456')
  log.debug "Pasw: #{enc}"
end

# file: cup_pgitem.rb
require 'rubygems'
require 'dbcup_datamodel'

module CupDbDataModel

  class CupPgItem < CupBasicDbModel
    attr_reader :fields
    attr_reader :status

    def initialize(fields={})
      #@log = Log4r::Logger["DbConnector"] use self.logger
      super(fields,{:table_name => 'pgitem',
                    :field_list => [:id, :owner_user_id, :game_name, :options, :status, :created_at, :updated_at, :saved_game],
                    # automatic done in base class => :fieldtypes => {:created_at => :datetime, :updated_at => :datetime}
      }) 
    end

    def self.get_model_name
      'CupPgItem'
    end 
    
    def delete_me(dbpg_conn)
      query = "DELETE FROM pgitem WHERE id = #{@id}"
      @log.debug query if @use_debug_sql
      return dbpg_conn.async_exec( query )
    end  

    ## provides all pgitem for the user user_id in status game_not_started
    # They are all pending game waiting to init.
    def self.find_init_pgitems_user(user_id, dbpg_conn)
      return nil if (user_id == '' || user_id == nil)
      query = "SELECT * from pgitem WHERE owner_user_id='#{dbpg_conn.escape_string(user_id)}' AND status = 'game_not_started'"
      return self.exec_sql_query(query, dbpg_conn)
    end

    def self.find_init_pgitems(dbpg_conn)
      query = "SELECT * from pgitem WHERE status = 'game_not_started'"
      return self.exec_sql_query(query, dbpg_conn)
    end

    def self.find_pgitems(dbpg_conn)
      query = "SELECT * from pgitem"
      return self.exec_sql_query(query, dbpg_conn)
    end

    #delete all pgitems for the user_id in status game_not_started.
    def self.delete_init_pgitems(user_id, dbpg_conn)
      return nil if (user_id == '' || user_id == nil)
      query = "DELETE FROM pgitem WHERE owner_user_id='#{dbpg_conn.escape_string(user_id)}' AND status = 'game_not_started'"
      return self.exec_sql_query(query, dbpg_conn)
    end

    def self.delete_all_pgitems(dbpg_conn)
      query = "DELETE FROM pgitem WHERE status = 'game_not_started'"
      return self.exec_sql_query(query, dbpg_conn)
    end

    def self.create_pgitem(pg_item, user_id, dbpg_conn)
      self.logger.debug("create pg_item in db")
      item = CupDbDataModel::CupPgItem.new
      item.owner_user_id = user_id
      item.game_name = pg_item.game
      item.options = pg_item.nal_server.info_hash.to_s
      item.status = pg_item.nal_server.state_game.to_s
      item.save(dbpg_conn)
      return self.get_last_id_inseq('pgitem_id_seq', dbpg_conn)
    end

    def self.delete_pgitem_on_id(id, dbpg_conn)
      return nil if (id == '' || id == nil)
      self.logger.debug("delete pg_item #{id} in db")
      query = "DELETE FROM pgitem WHERE id='#{dbpg_conn.escape_string(id)}' AND status = 'game_not_started'"
      return self.exec_sql_query(query, dbpg_conn)
    end

    def self.update_status_pgitem(id, status, dbpg_conn)
      avail = ["game_not_started","game_started","game_saved", "game_saved_indb"]
      if avail.index(status) == -1
        raise "status #{status} not allowed" 
      end
      self.logger.debug("update status #{status} for #{id} in db")
      query = "UPDATE pgitem SET status='#{dbpg_conn.escape_string(status)}' WHERE id='#{dbpg_conn.escape_string(id)}'"
      return self.exec_sql_query(query, dbpg_conn)
    end

  end

end#end module
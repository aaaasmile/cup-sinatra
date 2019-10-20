#file: dbcup_datamodel.rb
require 'rubygems'
require 'digest'
require 'time'

module CupDbDataModel

  class CupBasicDbModel

    def initialize(fields={},opt)
      @use_debug_sql = CupBasicDbModel.use_debug_sql
      @log = CupBasicDbModel.logger 
      @table_name = opt[:table_name]
      @fields = fields 
      @changed_fields = []
      @is_update = @fields.size > 0
      @field_types = {:updated_at => :datetime, :created_at => :datetime}
      raise "table_name #{@table_name} is undefined" unless (@table_name)
      if opt[:fieldtypes]
        @field_types = @field_types.merge(opt[:fieldtypes])
      end
      opt[:field_list] = [] unless opt[:field_list]
      opt[:field_list] << :updated_at
      opt[:field_list] << :created_at
      opt[:field_list].each do |fld|
        CupBasicDbModel.class_eval( 
              %{
                def #{fld.to_s}()
                  @#{fld.to_s}
                end

                def #{fld.to_s}=(new_val)
                  @#{fld.to_s} = new_val
                  #p method(#{fld})
                  item_name = '#{fld}'.to_sym
                  unless @changed_fields.index(item_name)
                    @changed_fields << '#{fld}'.to_sym
                  end
                  #p  @changed_fields
                end
              })
      end
      @fields.each do |k,v|
        self.instance_eval(%{
          @#{k.to_s} = parse_field_value('#{k}'.to_sym, v)
        })
      end
    end

    def self.logger
      unless @log
        @log = Log4r::Logger["DbConnector"]
        #p "created"
      end
      @log
    end

    def self.use_debug_sql
      #p "get value #{@use_debug_sql}"
      @use_debug_sql
    end

    def self.use_debug_sql=(value)
      @use_debug_sql = value
      #p "set value #{@use_debug_sql}"
    end

    def self.get_model_name
      raise "Please override self.get_model_name"
    end

    def is_newrecord?
      !@is_update
    end

    def save(dbpg_conn)
      self.updated_at = Time.now 
      if @is_update
        query = "UPDATE #{@table_name} SET #{get_changedfields(dbpg_conn)} WHERE " + get_where_on_pk
      else
        self.created_at = Time.now
        query = "INSERT INTO #{@table_name} (#{get_field_title}) VALUES (#{get_field_values(dbpg_conn)})"
      end
      exec_update_or_create(query, dbpg_conn)
    end

    def delete(dbpg_conn)
      query = "DELETE FROM #{@table_name} WHERE " + get_where_on_pk
      exec_update_or_create(query, dbpg_conn)
    end

    def get_field_title
      arr = @changed_fields.map{|e| e.to_s}
      arr.join(',')
    end

    def get_field_values(dbpg_conn)
      arr = @changed_fields.map{|f| "'" + dbpg_conn.escape_string(serialize_field_value(f,send(f))) + "'"}
      arr.join(',')
    end

    def get_changedfields(dbpg_conn)
      res = ""
      @changed_fields.each do |f|
        res = (res != "") ? res + "," : res
        val = dbpg_conn.escape_string(serialize_field_value(f,send(f)))
        res = res + "#{f}='#{val}'"  
      end
      return res
    end

    def get_where_on_pk
      "id='#{@id}'"
    end

    def make_token
      secure_digest(Time.now, (1..10).map{ rand.to_s })
    end

    def self.exec_sql_query_first(query, dbpg_conn)
      CupBasicDbModel.logger.debug query if CupBasicDbModel.use_debug_sql
      result = dbpg_conn.async_exec( query )  
      return nil if result.ntuples == 0
      return (eval(self.get_model_name)).new(result[0])
    end

    def self.exec_sql_query(query, dbpg_conn)
      CupBasicDbModel.logger.debug query if CupBasicDbModel.use_debug_sql
      result = dbpg_conn.async_exec( query )  
      return nil if result.ntuples == 0
      ret_res = []
      result.each do |item|
        if item.has_key?("count")
          ret_res << item["count"]
        else
          res_item = (eval(self.get_model_name)).new(item)
          ret_res << res_item
        end
      end
      return ret_res
    end

    def self.get_last_id_inseq(seq, dbpg_conn)
      query = "SELECT currval('#{seq}')"
      CupBasicDbModel.logger.debug query if CupBasicDbModel.use_debug_sql
      result = dbpg_conn.async_exec( query )  
      return nil if result.ntuples == 0
      #p result[0]
      return result[0]["currval"]
    end

    def exec_update_or_create(query, dbpg_conn)
      @log.debug query if @use_debug_sql
      dbpg_conn.async_exec(query)  
      @changed_fields = []
    end

    def serialize_field_value(field, value)
      if @field_types[field] == :datetime
        value.strftime("%Y-%m-%d %H:%M:%S")
      elsif @field_types[field] == :boolean
        res = value ? 1 : 0
      else
        value.to_s
      end
    end

    def parse_field_value(field, value_s)
      if @field_types[field] == :datetime
        res = value_s == nil ? nil : Time.parse(value_s)
      elsif @field_types[field] == :boolean
        res = value_s == '1' ? true : false
      elsif @field_types[field] == :int
        res = value_s == nil ? 0 : value_s.to_i
      elsif @field_types[field] == :float
        res = value_s == nil ? 0.0 : value_s.to_f
      else
        res = value_s
      end
      return res
    end
  end #end CupBasicDbModel
    
end #end module

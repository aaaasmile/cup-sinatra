#file list_cup_common.rb

require 'rubygems'
require 'database/dbconnector'

module MyGameServer
  ##
  # Common stuff for list in cuperativa server
class ListCupCommon
  
  def initialize(dir_log)
    @log = Log4r::Logger['serv_main']
    @dir_log = dir_log
    @db_connector = nil
  end

  ##
  # Create an hash for pg_list2 message
  def create_hash_forlist2(type_list, slice_nr, slice_state, arr_pgs)
    return { :type => type_list, 
             :slice => slice_nr,
             :slice_state =>  slice_state,
             :detail => arr_pgs }
  end
  
  def create_hash_forlist2addremove(type_list, detail_list)
    return {:type => type_list, :detail => detail_list}
  end
  
  def set_db_connector(db_connector)
    @db_connector = db_connector 
  end
  
end #end ListCupCommon
end
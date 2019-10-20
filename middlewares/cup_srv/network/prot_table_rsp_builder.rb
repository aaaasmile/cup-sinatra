#file: prot_table_rsp_builder.rb

$:.unshift File.dirname(__FILE__)

module ProtTableRspBuilder
  
  # CREATE FAILED
  def build_create_failed_TabRsp(game_name, reason)
    obj = {
      :game_name => game_name[:game_name],
      :reason => {:code => reason[:code], :msg => reason[:msg]},
      :art => :response 
    }
    if(obj[:game_name] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  # ADDED 
  def build_create_added_TabRsp(table_id, player_name, game_name, is_prive, pin, 
                             is_classific, opt_game)
    
     obj = {
        :table_id => table_id[:table_id],
        :game_name => game_name[:game_name], 
        :player_name => player_name[:player_name],
        :is_prive => is_prive[:is_prive], :pin => pin[:pin] ,
        :is_classific => is_classific[:is_classific],
        :opt_game => opt_game[:opt], 
        :art => :notification
    }
    
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
    
  end
  
  # REMOVED 
  def build_create_removed_TabRsp(table_id)
    
     obj = {
        :table_id => table_id[:table_id],
        :art => :notification
    }
    
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
    
  end
  
  
  def build_ready_to_send_table_req(req)
    info = JSON.generate(req)
    cmd_to_send = build_cmd(:table_rsp, info)
    return (cmd_to_send)
  end
  
end


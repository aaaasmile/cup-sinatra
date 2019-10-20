#file: prot_msg_table.rb

$:.unshift File.dirname(__FILE__)

module ProtTableReqBuilder
  
  ## CREATE
  def build_create_objTabReq(player_name, game_name, is_prive, pin, 
                             is_classific, opt_game)
    obj = {
      :game_name => game_name[:game_name], 
      :player_name => player_name[:player_name],
      :is_prive => is_prive[:is_prive], :pin => pin[:pin] ,
      :is_classific => is_classific[:is_classific],
      :opt_game => opt_game[:opt], 
      :cmd => :create_table
    }
      
    if(obj[:game_name] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## UPDATE
  def build_update_objTabReq(table_id, 
                             player_name, game_name, 
                             is_classific, opt_game)
    obj = {
      :table_id => table_id[:table_id],
      :game_name => game_name[:game_name], 
      :player_name => player_name[:player_name],
      :is_classific => is_classific[:is_classific],
      :opt_game => opt_game[:opt], 
      :cmd => :update_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## LIST
  def build_list_objTabReq(player_name, page_ix, page_size)
    obj = {
      :player_name => player_name[:player_name],
      :page_ix => page_ix[:page_ix], 
      :page_size =>  page_size[:page_size],
      :cmd => :list_table
    }
      
    if(obj[:player_name] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## REMOVE
  def build_remove_objTabReq(table_id, player_name)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :cmd => :remove_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## SHOW
  def build_show_objTabReq(table_id, player_name)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :cmd => :show_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  
  ## SEAT_DOWN
  def build_seat_down_objTabReq(table_id, player_name)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :cmd => :seat_down_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## SEAT_UP
  def build_seat_up_objTabReq(table_id, player_name)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :cmd => :seat_up_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## ENTER
  def build_enter_objTabReq(table_id, player_name, pin)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :pin => pin[:pin],
      :cmd => :enter_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## LEAVE
  def build_leave_objTabReq(table_id, player_name)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :pin => pin[:pin],
      :cmd => :leave_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## ALLOW_SEATDOWN
  def build_allow_seatdown_objTabReq(table_id, player_name, player_that_seat)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :player_that_seat => player_that_seat[:player_name],
      :pin => pin[:pin],
      :cmd => :allow_seatdown_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  ## REFUSE_SEATDOWN
  def build_refuse_seatdown_objTabReq(table_id, player_name, player_that_seat)
    obj = {
      :table_id => table_id[:table_id],
      :player_name => player_name[:player_name],
      :player_that_seat => player_that_seat[:player_name],
      :pin => pin[:pin],
      :cmd => :refuse_seatdown_table
    }
      
    if(obj[:table_id] == nil)
      raise "Game name invalid"
    end
      
    return obj
  end
  
  
  def build_ready_to_send_table_req(req)
    info = JSON.generate(req)
    cmd_to_send = build_cmd(:table_req, info)
    return (cmd_to_send)
  end
  
end


if $0 == __FILE__
  require 'rubygems'
  require 'log4r'
  require 'yaml'
  
  include Log4r
  log = Log4r::Logger.new("serv_main")
  log.outputters << Outputter.stdout
  
  require 'prot_buildcmd'
  
  include ProtBuildCmd
  include ProtTableReqBuilder
  
  p req = build_create_objTabReq(
        {:player_name => "luzzo"}, {:game_name => "Mariazza"},
        {:is_prive => true}, {:pin => '1234'}, {:is_classific => false},                            
        {:opt =>{:target_points_segno => 41, :num_segni_match => 1}}
        )
  p msg_to_send = build_ready_to_send_table_req(req)
end
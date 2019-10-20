#file: cup_classifica.rb

require 'rubygems'
require 'dbcup_datamodel'

module CupDbDataModel

###########  CupClassifica #############################
class CupClassifica < CupBasicDbModel
  attr_reader :fields
  def initialize(fields={})
    super(fields,{:table_name => 'classifica',
                  :field_list => [:id,:name,:type,:match_percent,:match_won,:match_losed,:match_tiedup,
                                  :legs_won,:legs_losed,:legs_tiedup,:score,:title_level,:user_id,:tot_matchpoints],
                  :fieldtypes => {:match_percent=>:float, :match_won=>:int, :match_losed=>:int, :match_tiedup=>:int,
                                  :legs_won=>:int, :legs_losed=>:int, :legs_tiedup=>:int, :score=>:int, :tot_matchpoints => :int}
                 })  

    reset_inc
    
    if fields.size == 0
      self.match_won = 0
      self.match_losed = 0
      self.match_tiedup = 0 
      self.legs_won = 0
      self.legs_losed = 0
      self.legs_tiedup = 0
      self.score = 0
    end
  end

  def self.get_model_name
    'CupClassifica'
  end

  def reset_inc
    @inc_match_won = @inc_match_losed = @inc_match_tiedup = @inc_legs_won = @inc_legs_losed = @inc_legs_tiedup = @inc_score = 0
  end

  def self.find_by_user_id(game_name, user_id, type, dbpg_conn)
    return nil if (user_id == '' || user_id == nil)
    query = "SELECT * from classifica WHERE user_id='#{user_id}' AND name='#{game_name}' AND type='#{type}'"
    return self.exec_sql_query_first(query, dbpg_conn)
  end

  def self.type_current
    'M'
  end

  def score=(newval)
    @inc_score += newval - @score if @score 
    super(newval)
  end

  def match_won=(newval)
    @inc_match_won += newval - @match_won if @match_won
    super(newval)
  end

  def match_losed=(newval)
    @inc_match_losed += newval - @match_losed if @match_losed
    super(newval)
  end

  def match_tiedup=(newval)
    @inc_match_tiedup += newval - @match_tiedup if @match_tiedup
    super(newval)
  end

  def legs_won=(newval)
    @inc_legs_won += newval - @legs_won if @legs_won
    super(newval)
  end

  def legs_losed=(newval)
    @inc_legs_losed += newval - @legs_losed if @legs_losed
    super(newval)
  end

  def legs_tiedup=(newval)
    @inc_legs_tiedup += newval - @legs_tiedup if @legs_tiedup
    super(newval)
  end

  def save(dbpg_conn)
    class_year = nil
    if @type == 'M'
      #p 'game name: ' + @name
      #p @user_id
      class_year = CupClassifica.find_by_user_id(@name, @user_id, 'Y', dbpg_conn)
      unless class_year 
        @log.debug "Create the yearly item"
        class_year = CupClassifica.new
        class_year.name = @name
        class_year.type = 'Y'
        class_year.user_id = @user_id
      end
      #p class_year
      class_year.match_won += @inc_match_won
      class_year.match_losed += @inc_match_losed 
      class_year.match_tiedup +=  @inc_match_tiedup
      tot = class_year.match_won + class_year.match_losed + class_year.match_tiedup
      if tot > 0
        class_year.match_percent = (class_year.match_won * 100 ) / tot 
      end
      class_year.legs_won +=  @inc_legs_won
      class_year.legs_losed +=  @inc_legs_losed
      class_year.legs_tiedup +=  @inc_legs_tiedup
      class_year.score +=  @inc_score
      class_year.save(dbpg_conn)
    end
    super(dbpg_conn)
    reset_inc
  end
end# end CupClassifica

end# end CupDbDataModel
#file: zero_classifica.rb
# used to change classificas. This script is used as standalone script.

require 'rubygems'
require 'dbconnector'
require 'log4r'
require 'dbcup_datamodel'

include Log4r


class ZeroScoreClassificas < MyGameServer::BasicDbConnector
  attr_accessor :all_score_tozero
  
  def initialize
    super
    @log = Log4r::Logger.new("connector::ZeroScoreClassificas") 
    # CAUTION: if this is true force ALL records to the default value
    @all_score_tozero = false
    
    @tables_class = ['CupDbDataModel::ClassificaBri2', 'CupDbDataModel::ClassificaMariazza',
              'CupDbDataModel::ClassificaSpazzino', 'CupDbDataModel::ClassificaTombolon',
              'CupDbDataModel::ClassificaScopetta', 'CupDbDataModel::ClassificaTressette', 'CupDbDataModel::ClassificaBriscolone' ]
  end
  
  ##
  # Players that not have any match becomes a zero score
  def check_and_set_zeroscore
    @tables_class.each do |str_table|
      allitems = (eval(str_table)).find(:all)
      @log.debug "Processing table #{str_table}"
      allitems.each do |item|
        if item.match_losed == 0 and item.match_won == 0 and item.score == 1000 or 
                  @all_score_tozero
          item.default_classifica 
          @log.debug "Set score to zero (default) for user #{item.user_id}"
          item.save
        end
      end 
    end# end tables
  end
  
  ##
  # Recalculate percent score for all classificas
  def recalculate_percent
    @tables_class.each do |str_table|
      allitems = (eval(str_table)).find(:all)
      @log.debug "Processing table #{str_table}"
      allitems.each do |item|
        tot = item.match_won + item.match_losed
        next if tot <= 0
        old_val = item.match_percent
        item.match_percent = (item.match_won * 100 )/ tot
        @log.debug "Set percent: #{item.match_percent} %"
        if old_val != item.match_percent
          @log.debug "Calculation differ for user #{item.user_id}, old: #{old_val}"
        end
        item.save       
      end
      
    end
  end
  
  ##
  # Save all classificas into a csv file
  def save_class_tofile
    curr_day = Time.now.strftime("%Y_%m_%d")
    base_dir_out = File.dirname(__FILE__) + "/csv/#{curr_day}"
    FileUtils.mkdir_p(base_dir_out)
    
    @tables_class.each do |str_table|
      allitems = (eval(str_table)).find(:all)
      @log.debug "Processing table #{str_table}"
      strdet = []
      strdet << "Table: #{str_table}"
      strdet << allitems[0].attributes.keys.join(",") if allitems.size > 0
      allitems.each do |item|
        strdet << item.attributes.values.join(",")         
      end
      fname = File.join(base_dir_out, "#{str_table.split("::")[1]}.csv")
      File.open(fname, 'w') do |out|
        out << strdet.join("\n")
      end
      @log.debug "File created: #{fname}"
    end
  end
  
  
end

if $0 == __FILE__
  zeros = ZeroScoreClassificas.new
  #zeros.check_and_set_zeroscore
  #zeros.save_class_tofile
  #zeros.recalculate_percent
end

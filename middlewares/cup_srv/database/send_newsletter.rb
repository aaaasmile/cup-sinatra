#file: send_newsletter.rb

require 'rubygems'
require 'net/smtp'

require 'dbconnector'
require 'log4r'
require 'dbcup_datamodel'

include Log4r

class NewsletterSender < MyGameServer::BasicDbConnector
  
  def initialize
    super
    @log = Log4r::Logger.new("connector::NewsletterSender") 
  end
  
  def run
    @log.debug "Prepare to send newsletter"
    all_user = CupDbDataModel::CupUser.find(:all)
    proc = 0
    all_user.each do |user|
      @log.debug "Send newsletter to #{user.login}"
      proc += 1
    end
    @log.debug "Tot sent items #{proc}"
  end
  
  
end



if $0 == __FILE__
  ns = NewsletterSender.new
  ns.run
end

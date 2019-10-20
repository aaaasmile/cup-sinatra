#file: sendemail_errors.rb
# Use to send an email when an error occours.

require 'rubygems'
require 'net/smtp'

class EmailErrorSender
  
  def initialize(log)
    @log = log
    @destination = 'todo' # google account
    @from = 'todo' # google account
    @uniq = 0
  end

  def send_email(detail)
    if ENV['RACK_ENV'] != 'production'
      puts "Not a production env, no email sent"
      p [:rack_env, ENV['RACK_ENV']]
      return
    end
    msgstr = <<END_OF_MESSAGE
From: Cuperativa <todo>
Subject: Errore (#{Time.now}) da Cuperativa.invido.it
Date: #{Time.now}
Mime-Version: 1.0
Content-Type: text/plain; charset=UTF-8
Message-Id: <#{random_tag()}@invido.it>

Ciao,

se ti interessa un nuovo errore:

#{detail}

fai come vuoi,

Cuperativa Server

END_OF_MESSAGE
    
    #p msgstr
    #Net::SMTP.start('aspmx.l.google.com', 25, 'mail.from.domain',
    #            'Your Account', 'Your Password', :plain)
    Net::SMTP.start('aspmx.l.google.com', 25) do |smtp|
      smtp.send_message msgstr,
                      @from,
                      @destination
    end

    @log.debug("Email with log report was sent OK.")
    rescue
    # send error
    @log.error("send_email error detail is failed. Reason #{$!}")
  end
  
  ##
  # Provides a random tag
  def random_tag
    @uniq += 1
    t = Time.now
    sprintf('%x%x_%x%x%d%x',
            t.to_i, t.tv_usec,
            $$, Thread.current.object_id, @uniq, rand(255))
  end
  
end
       
       
if $0 == __FILE__
  require 'log4r'
  include Log4r
  
  Log4r::Logger.new("email_log_notifier")
  Log4r::Logger['email_log_notifier'].outputters << Outputter.stdout
  mylog = Log4r::Logger['email_log_notifier']
  
  sender = EmailErrorSender.new(mylog)
  sender.send_email("Un error grave nel file aa.eb linea 123.")
  
end
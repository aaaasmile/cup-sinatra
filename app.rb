require 'rubygems'
require 'sinatra'
require 'log4r'
include Log4r

                                            
class App < Sinatra::Application
  Log4r::Logger.new("SinatraMyLogErr")
  Log4r::Logger['SinatraMyLogErr'].outputters << Outputter.stdout

  configure do
    set :logging, Log4r::Logger['SinatraMyLogErr']
    use Rack::CommonLogger, @log
  end

  get '/' do
    redirect 'index.html'
  end
  
end
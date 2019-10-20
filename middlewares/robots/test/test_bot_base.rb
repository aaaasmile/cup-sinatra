# file: test_bot_base.rb
# file used to test GameBasebot

require 'rubygems'
require 'test/unit'
require 'log4r'
require 'yaml'

PATH_TO_ROBOTS = File.expand_path(File.dirname(__FILE__) + '/..')
PATH_TO_CLIENT = File.expand_path(File.dirname(__FILE__) + '/../..')
PATH_TO_SERVER = File.expand_path(File.dirname(__FILE__) + '/../../../server')

$:.unshift( PATH_TO_CLIENT )


require File.join( PATH_TO_CLIENT, 'base/core_game_base')
require File.join( PATH_TO_ROBOTS, 'bot_base')
require File.join( PATH_TO_CLIENT, 'network/prot_parsmsg')
require File.join( PATH_TO_CLIENT, 'network/client/control_net_conn')
require File.join( PATH_TO_CLIENT, 'network/client/nal_client_gfx')
require File.join( PATH_TO_SERVER, 'nal_srv_algorithm')
include Log4r

##
# Test suite for game base bot
class Test_Botbase < Test::Unit::TestCase
  
  def setup
    @log = Log4r::Logger.new("coregame_log")
  end
  

  ##
  # Make a test if all methods on AlgCpuPlayerBase are implemented
  def test_interfaces
    # collect methods implemented only in GameBasebot
    aa =  GameBasebot.instance_methods(false)
    unsupp = []
    alg_int = AlgCpuPlayerBase.new
    AlgCpuPlayerBase.instance_methods(false).each do |m|
      if m =~ /onalg/
        if aa.index(m)
          #puts "Method #{m} supported"
        else
          puts "Method #{m} UNSPORRTED"
          unsupp << m
        end
      end
    end
    # usupported must be 0
    assert_equal(0,unsupp.size)
  end
  
  ##
  # Test if ControlNetConnection has implemented all methods
  def testControlNetInterface
    unsupp = []
    mets = ControlNetConnection.instance_methods(false)
    AlgCpuPlayerBase.instance_methods(false).each do |m_item|
      m = "cmdh_#{m_item}"
      if m_item =~ /onalg/
        if mets.index(m)
          #puts "Method #{m} supported"
        else
          puts "Method #{m} UNSPORRTED"
          unsupp << m
        end
      end
    end
    # usupported must be 0
    assert_equal(0,unsupp.size)
  end

  ##
  # Test if ParserCmdDef has implemented all methods
  def testParserCmdDefInterface
    unsupp = []
    unsupp_hndl = []
    mets = ProtCommandConstants::SUPP_COMMANDS
    #p mets.keys
    AlgCpuPlayerBase.instance_methods(false).each do |m_item|
      if m_item =~ /onalg/
        m = m_item.to_sym
        if mets.keys.index(m)
          #puts "Method #{m} supported"
          cmdh_info = mets[m][:cmdh]
          if cmdh_info.to_s != "cmdh_#{m}"
            #p cmdh_info
            puts "Handler method #{m} UNSPORRTED"
            unsupp_hndl << m
          end 
        else
          puts "Method #{m} UNSPORRTED"
          unsupp << m
        end
      end
    end
    # usupported must be 0
    assert_equal(0,unsupp.size)
    assert_equal(0,unsupp_hndl.size)
  end

  ##
  # Test if NalClientGfx has implemented all methods
  def testNalClientGfxInterface
    unsupp = []
    mets = NalClientGfx.instance_methods(false)
    AlgCpuPlayerBase.instance_methods(false).each do |m_item|
      m = "#{m_item}"
      if m_item =~ /onalg/
        if mets.index(m)
          #puts "Method #{m} supported"
        else
          puts "Method #{m} UNSPORRTED"
          unsupp << m
        end
      end
    end
    # usupported must be 0
    assert_equal(0,unsupp.size)
  end

    
  ##
  # Test if NAL_Srv_Algorithm has implemented all methods
  def testNAL_Srv_AlgorithmInterface
    unsupp = []
    mets = MyGameServer::NAL_Srv_Algorithm.instance_methods(false)
    AlgCpuPlayerBase.instance_methods(false).each do |m_item|
      m = "#{m_item}"
      if m_item =~ /onalg/
        if mets.index(m)
          #puts "Method #{m} supported"
        else
          puts "Method #{m} UNSPORRTED"
          unsupp << m
        end
      end
    end
    # usupported must be 0
    assert_equal(0,unsupp.size)
  end
end
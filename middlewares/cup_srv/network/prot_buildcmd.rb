#file: prot_buildcmd.rb

$:.unshift File.dirname(__FILE__)

require 'prot_constants'

module ProtBuildCmd
  ##
  # Provides the command string ready to send
  def build_cmd(cmd_lit, cmddet)
    if cmd_lit == :login_ok
      p [:build_cmd, cmd_lit, '....']
    else   
      p [:build_cmd, cmd_lit, cmddet] 
    end
    cmd = "#{ProtCommandConstants::SUPP_COMMANDS[cmd_lit][:liter]}:#{cmddet}" << ProtCommandConstants::CRLF
    return cmd
  end
end
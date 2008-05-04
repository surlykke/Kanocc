#  
#  Copyright 2008 Christian Surlykke
#
#  This file is part of Kanocc.
#
#  Kanocc is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License, version 3 
#  as published by the Free Software Foundation.
#
#  Kanocc is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License, version 3 for more details.
#
#  You should have received a copy of the GNU General Public License,
#  version 3 along with Kanocc.  If not, see <http://www.gnu.org/licenses/>.
#
require 'stringio'
require 'strscan'
require 'logger'

module Kanocc
  class Scanner
    attr_accessor :logger
    def initialize(init = {})
      if init[:logger]
        @logger = init[:logger] 
      else
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::WARN
      end
      @ws_regs = [/\s/]
      @recognizables = []
      @regexps = []
    end
    
    def set_whitespace(*ws_regs)
      @ws_regs = []
      ws_regs.each do |ws_reg| 
        unless ws_reg.is_a?(Regexp)
          raise "setWhitespace must be given a list of Regexp's" 
        end
        @ws_regs << ws_reg
      end
    end
    
    def set_recognized(*rec)
      @recognizables = []
      @regexps = []
      rec.each do |r| 
        @recognizables << r
        if r.class == Class
	  @regexps << r.pattern
        else
          @regexps << Regexp.compile(Regexp.escape(r))
        end
      end
    end
    
    def each_token(input)
      if input.is_a?(IO) 
        @input = input.readlines.join("")
      elsif input.is_a?(String) 
        @input = input
      else
        raise "Input must be a string or an IO object"
      end 
      @stringScanner = StringScanner.new(@input)
      pos = @stringScanner.pos 
      while tokens = next_token do
        @logger.debug("Yielding with #{tokens}, #{pos}, #{@stringScanner.pos}")
        yield(tokens, pos, @stringScanner.pos)
	pos = @stringScanner.pos
      end
    end
  
    private
    
    def next_token
       
      while true do 
        if @stringScanner.pos >= @input.length
          return nil 
	end
	tokens = match_token
        
	if tokens.size > 0 
          @logger.debug("nextToken returning #{tokens}")
          return tokens
        elsif trim_whitespace
          # Now we've stripped some whitespace, so we go
          # back and try to match a token again
          next
        else
          # We've not been able to recognize a token or whitespace, 
          # so we emit the first character of the remaining input as a string literal.
          # With this behavior, lexical scanning cannot fail.
          res = [@stringScanner.scan(/./m)]
          @logger.debug("nextToken returning #{res.inspect}")
          return res 
        end
      end
    end
    
    def match_token
      reg_poss = find_matching_reg(@regexps) 
      @logger.debug("matchToken, regPoss = #{reg_poss.inspect}");  
      tokens = []
      str = nil
      reg_poss.each do |i|
        logger.debug("@recognizables[#{i}] = #{@recognizables[i].inspect}") 
        str = @stringScanner.scan(@regexps[i]) unless str 
	if @recognizables[i].class == Class
	  @logger.debug("Its a class")
	  token = @recognizables[i].new(str)
	  token.m = token.match(str) # To create a proper match object
	  @logger.debug("token: " + token.inspect) 
	  tokens << token 
	  @logger.debug("tokens: " + tokens.inspect)
	else
	  tokens << str
        end
      end
      @logger.debug("matchToken returning: " + tokens.inspect)
      return tokens  
    end
    
    def trim_whitespace
      ws_poss = find_matching_reg(@ws_regs)
      if  ws_poss.size > 0
	@stringScanner.skip(@ws_regs[ws_poss[0]])
        return true
      else
	return false
      end
    end
        
    def find_matching_reg(arrayOfRegs)
      @logger.debug("findMatchingReg: arrayOfRegs = #{arrayOfRegs}")
      max_length = 0
      reg_poss = []
      for i in 0..arrayOfRegs.size-1 do 
	len = @stringScanner.match?(arrayOfRegs[i]) || 0	
	if len > max_length
	  reg_poss = [i]
	  max_length = len
	elsif len == max_length and len > 0
	  reg_poss << i
	end
      end
      return reg_poss
    end
  end
end


############################################
#                Testing
#require 'Token'
#
#class Number < Token
#  set_pattern(/\d+/)
#end
#
#scanner = KanoccScanner.new
#scanner.set_recognized(Number, "Exit")
#scanner.set_whitespace(/[ \t]/)
#
#scanner.eachTokenDo{|token|  print token.inspect, "\n"}

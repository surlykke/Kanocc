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
      @wsRegs = [/\s/]
      @recognizables = []
      @regexps = []
    end
    
    def setWhitespace(*wsRegs)
      @wsRegs = []
      wsRegs.each do |wsReg| 
        unless wsReg.is_a?(Regexp)
          raise "setWhitespace must be given a list of Regexp's" 
        end
        @wsRegs << r
      end
    end
    
    def setRecognized(*rec)
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
    
    def eachToken(input)
      if input.is_a?(IO) 
        @input = input.readlines.join("")
      elsif input.is_a?(String) 
        @input = input
      else
        raise "Input must be a string or an IO object"
      end 
      @stringScanner = StringScanner.new(@input)
      pos = @stringScanner.pos 
      while tokens = nextToken do
        @logger.debug("Yielding with #{tokens}, #{pos}, #{@stringScanner.pos}")
        yield(tokens, pos, @stringScanner.pos)
	pos = @stringScanner.pos
      end
    end
  
    private
    
    def nextToken
       
      while true do 
        if @stringScanner.pos >= @input.length
          return nil 
	end
	tokens = matchToken
        
	if tokens.size > 0 
          @logger.debug("nextToken returning #{tokens}")
          return tokens
        elsif trimWhitespace
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
    
    def matchToken
      regPoss = findMatchingReg(@regexps) 
      @logger.debug("matchToken, regPoss = #{regPoss.inspect}");  
      tokens = []
      str = nil
      regPoss.each do |i|
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
    
    def trimWhitespace
      wsPoss = findMatchingReg(@wsRegs)
      if  wsPoss.size > 0
	@stringScanner.skip(@wsRegs[wsPoss[0]])
        return true
      else
	return false
      end
    end
        
    def findMatchingReg(arrayOfRegs)
      @logger.debug("findMatchingReg: arrayOfRegs = #{arrayOfRegs}")
      maxLength = 0
      regPoss = []
      for i in 0..arrayOfRegs.size-1 do 
	len = @stringScanner.match?(arrayOfRegs[i]) || 0	
	if len > maxLength
	  regPoss = [i]
	  maxLength = len
	elsif len == maxLength and len > 0
	  regPoss << i
	end
      end
      return regPoss
    end
  end
end


############################################
#                Testing
#require 'Token'
#
#class Number < Token
#  setPattern(/\d+/)
#end
#
#scanner = KanoccScanner.new
#scanner.setRecognized(Number, "Exit")
#scanner.setWhitespace(/[ \t]/)
#
#scanner.eachTokenDo{|token|  print token.inspect, "\n"}

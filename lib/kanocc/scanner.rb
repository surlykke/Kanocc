#  
#  Copyright 2008 Christian Surlykke
#
#  This file is part of Kanocc.
#require 'logger'

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
require "logger"
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
          raise "set_whitespace must be given a list of Regexp's" 
        end
        @ws_regs << ws_reg
      end
    end
    
    def set_recognized(*rec)
      @recognizables = []
      rec.each do |r| 
        if r.class == Class and r.ancestors.include?(Token)
	  @recognizables = @recognizables + r.patterns
        elsif r.is_a? String
          @recognizables << {:literal => r,
	                     :regexp  => Regexp.new(Regexp.escape(r))}
        else
          raise "set_recognized must be given a list of Tokens classes and or strings"
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
      while match = do_match do
        if match[:matches] 
          @logger.debug("Yielding #{match}")
          yield(match)
        end
        @stringScanner.pos += match[:length]
      end
    end

    private
    
    def do_match
      if @stringScanner.pos >= @stringScanner.string.length
        return nil;
      end
      
      token_match = match_token
      whitespace_match = match_whitespace
      
      if whitespace_match[:length] > token_match[:length]
        return whitespace_match
      elsif token_match[:length] > 0
        return token_match
      else 
	# So we've not been able to match tokens nor whitespace.
        # We return the first character of the remaining input as a string
        # literal
        string = @stringScanner.string.slice(@stringScanner.pos, 1)
        matches = [{:literal => string, 
	            :regexp  => Regexp.new(Regexp.escape(string))}] 
	return {:matches => matches,
	        :string => string,
	        :start_pos => @stringScanner.pos,
		:length => 1}
      end
    end

    def match_token
      matches = []
      max_length = 0 
      @recognizables.each do |rec| 
	if (len = @stringScanner.match?(rec[:regexp])) and len > 0 
	  if len > max_length
            # Now, we have a match longer than whatever we had, 
            # so we discharge what we had, and save the new one
            matches = [rec]
            max_length = len
          elsif len == max_length
            # This regular expression matches a string of same length 
            # as our previous match, so we prepare to return both
            matches << rec 
          end
        end
      end
      start_pos = @stringScanner.pos
      string = @stringScanner.string.slice(start_pos, max_length)
      return {:matches => matches, 
	      :string  => string, 
	      :start_pos => start_pos, 
	      :length => max_length}
    end
    
    def match_whitespace
      max_length = 0
      for i in 0..@ws_regs.size - 1 do
        len = @stringScanner.match?(@ws_regs[i]) || 0
        if len > max_length
          max_length = len
        end
      end
      string = @stringScanner.string.slice(@stringScanner.pos, max_length)        
      result = {:string => string, 
	        :start_pos => @stringScanner.pos, 
	        :length => max_length}
      return result
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



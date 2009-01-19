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
require "logger"
require 'rubygems'
require 'ruby-debug'
module Kanocc
  class Scanner
    attr_accessor :logger, :current_match

    def initialize(init = {})
      @logger = init[:logger] 
      unless @logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::WARN
      end
      @ws_regs = [/\s/]
      @recognizables = []
      @regexps = []
      @input = ""
      @stringScanner = StringScanner.new(@input)
    end
    
    def set_whitespace(*ws_regs)
      raise "set_whitespace must be given a list of Regexp's" \
	if ws_regs.find {|ws_reg| not ws_reg.is_a?(RegExp)}

      @ws_regs = ws_regs
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
          raise "set_recognized must be given a list of Tokens classes and or strings, got #{rec.inspect}"
        end
      end
    end
   
    def input=(input)
      @input = input
      @stringScanner = StringScanner.new(@input)
    end

    def next_match!
      @current_match = do_match!
      return @current_match
    end

    private 

    def do_match!
      if @stringScanner.pos >= @stringScanner.string.length
        return nil;
      end
      if (token_match = match_token)[:length] > 0
        @stringScanner.pos += token_match[:length] 
	return token_match
      elsif (whitespace_len = match_whitespace) > 0
        @stringScanner.pos += whitespace_len 
	return do_match!
      else 
	# So we've not been able to match tokens nor whitespace.
        # We return the first character of the remaining input as a string
        # literal
        string = @stringScanner.string.slice(@stringScanner.pos, 1)
        @stringScanner.pos += 1 
	matches = [{:literal => string, 
	            :regexp  => Regexp.new(Regexp.escape(string))}] 
	return {:matches => matches,
	        :string => string,
	        :start_pos => @stringScanner.pos,
		:length => 1}
      end
    end

    private
 
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
      # Pack up what we found in a hash and return it 
      return {:matches => matches, 
	      :string  => string, 
	      :start_pos => start_pos, 
	      :length => max_length}
    end
    
     
    def match_whitespace
      max_len = 0
      for i in 0..@ws_regs.size - 1 do
        len = @stringScanner.match?(@ws_regs[i]) || 0
        if len > max_len
          max_len = len
        end
      end
      return max_len 
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



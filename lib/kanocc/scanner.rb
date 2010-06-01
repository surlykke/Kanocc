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
module Kanocc
  class Scanner
    attr_accessor :logger, :current_match, :input

    def initialize(init = {})
      @logger = init[:logger] 
      unless @logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::WARN
      end
      @ws_regs = [/\s/]
      @terminals = []
      @string_patterns = {}
      @input = ""
      @stringScanner = StringScanner.new(@input)
      @current_match = nil
    end
    
    def set_whitespace(*ws_regs)
      raise "set_whitespace must be given a list of Regexp's" \
	if ws_regs.find {|ws_reg| not ws_reg.is_a?(Regexp)}

      @ws_regs = ws_regs
    end
    
    def set_recognized(*recognizables)
      @recognizables = []
      @literals = []
      @tokens = []
      @string_patterns = {}
      recognizables.each do |recognizable|
	unless (recognizable.class == Class and recognizable.ancestors.include?(Token)) or
	       recognizable.is_a?(String)
          raise "set_recognized must be given a list of Tokens classes" +
	        "and or strings, got #{recognizable.inspect}"
	end
	@recognizables << recognizable
	if recognizable.is_a? String
	  @string_patterns[recognizable] = Regexp.new(Regexp.escape(recognizable))
	  @literals << recognizable
	else
	  @tokens << recognizable
	end
      end
    end
   
    def input=(input)
      @input = input
      @stringScanner = StringScanner.new(@input)
      @current_match = nil
    end

    def next_match!
      do_match!
      return @current_match
    end

    private 

    def do_match!
      if @stringScanner.pos >= @input.length
	@current_match = nil
      elsif match_token
        @stringScanner.pos += @current_match.length
      elsif (whitespace_len = match_whitespace) > 0
        @stringScanner.pos += whitespace_len
	do_match! 
      else 
	# So we've not been able to match tokens nor whitespace.
        # We return the first character of the remaining input as a string
        # literal
	str = @stringScanner.string.slice(@stringScanner.pos, 1)
	regexp = Regexp.new(Regexp.escape(str))
	@current_match = LexicalMatch.new([str], {str=>regexp}, @stringScanner.pos, 1)
	@stringScanner.pos += 1
      end
    end


    private
 
    def match_token
      matching_terminals = []
      regexps = {}
      max_length = 0 
      @recognizables.each do |recognizable|
	len, regexp = match(recognizable)
	if len > 0
	  if len > max_length
            # Now, we have a match longer than whatever we had, 
            # so we discharge what we had, and save the new one
            matching_terminals = [recognizable]
            regexps = {recognizable => regexp}
	    max_length = len
          elsif len == max_length
            # This regular expression matches a string of same length 
            # as our previous match(es), so we prepare to return both/all
            matching_terminals << recognizable
	    regexps[recognizable] = regexp
          end
        end
      end
      if max_length == 0
	return false
      else
	@current_match = LexicalMatch.new(matching_terminals, regexps, @stringScanner.pos, max_length)
	return true
      end
    end

    def match(recognizable)
      if recognizable.class == Class # It must be a token
	return recognizable.match(@stringScanner)
      elsif (len = @stringScanner.match?(@string_patterns[recognizable])) and len > 0
	return len, @string_patterns[recognizable]
      else
	return 0, nil
      end
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


    def do_match2!
      while @stringScanner.pos < @input.length do
	look_for_token_match
	look_for_whitespace_match

	if @whitespace_match_length > @match_length
	  @stringScanner.pos  += @whitespace_match_length
	elsif @match_length > 0
	  @current_match = LexicalMatch.new(@matching_recognizables, @regexps, @stringScanner.pos, @match_length)
	  @stringScanner.pos += @match_length
	  break
	else
          str = @stringScanner.string.slice(@stringScanner.pos, 1)
          regexp = Regexp.new(Regexp.escape(str))
          @current_match = LexicalMatch.new([str], {str=>regexp}, @stringScanner.pos, 1)
          @stringScanner.pos += 1
	  break
	end
      end
    end

    def look_for_token_match
      @matching_recognizables = []
      @regexps = {}
      @match_length = 0
      @tokens.each do |token|
	new_match_length, regexp = token.match(@stringScanner)
	if new_match_length > match_length
	  @matching_recognizables = [token]
	  @regexps = {token => regexp}
	  @match_length = new_match_length
	elsif new_match_length > 0 and new_match_length == match_length
	  @matching_recognizables << token
	  @regexps[token] = regexp
	end
      end
      @literals.each do |literal|
	new_match_length = @stringScanner.match?(@string_patterns[literal])
	if new_match_length > match_length
	  matching_recognizables = [literal]
	  regexps = {literal => @string_patterns[literal]}
	  match_length = new_match_length
	elsif new_match_length > 0 and new_match_length == match_length
	  matching_recognizables << literal
	  regexps[literal] = @string_paterns[literal]
	end
      end
    end

    def look_for_whitespace_match
      @whitespace_match_length = 0
      for i in 0..@ws_regs.size - 1 do
        len = @stringScanner.match?(@ws_regs[i]) || 0
        if len > @whitespace_match_length
          @whitespace_match_length = len
        end
      end
    end



  end

  class LexicalMatch
    attr_accessor :terminals, :start_pos, :length

    def initialize(terminals, regexps, start_pos, length)
      @terminals = terminals
      @regexps = regexps
      @start_pos = start_pos
      @length = length
    end

    def regexp(terminal)
      @regexps[terminal]
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



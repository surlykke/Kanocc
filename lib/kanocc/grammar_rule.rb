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
require 'rubygems'
require 'ruby-debug'
module Kanocc
  class GrammarRule
    attr_reader :lhs, :rhs, :method
    attr_accessor :precedence

    def initialize(lhs, rhs, method)
      @lhs = lhs
      @rhs = rhs
      @method = method
      @prededence = 0
      @logger.debug("#{lhs} --> #{rhs.map {|gs| gs.is_a?(Symbol) ? gs.to_s : gs}.join}, #prec = #{@prec}, method = #{method}") if @logger
    end  
   
    def rightmost_operator
      tokens = rhs.find_all{|gs| gs.is_a?(String) or gs.is_a?(Token)}
      if (tokens.size > 0)
	tokens[tokens.size - 1]
      else
	nil
      end
    end

    def inspect 
      return lhs.inspect + " ::= " + rhs.map{|gs| gs.inspect}.join(" ")
    end

  end
end  

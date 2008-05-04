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
module Kanocc
  class GrammarRule
    attr_reader :lhs, :rhs, :method, :operator_prec
    attr_accessor :prec 

    def initialize(lhs, rhs, method)
      @lhs = lhs
      @rhs = rhs
      @method = method
      if (operator =rhs.find {|s| s.is_a?(String) or s.is_a?(Token)})
        @operator_prec = Nonterminal.operator_precedence(operator) 
      end
      @prec = 0
      @logger.debug("#{lhs} --> #{rhs.map {|gs| gs.is_a?(Symbol) ? gs.to_s : gs}.join}, #prec = #{@prec}, method = #{method}") unless not @logger
    end
  
    def operator_prec
      unless @operator_prec_calculated
          operator = rhs.find {|s| s.is_a?(String) or s.is_a?(Token)}  
          if operator
            @operator_prec = lhs.operator_precedence(operator)
          end
          @operator_prec_calculated = true
      end
      @operator_prec
    end
    
    def inspect 
      return lhs.inspect + " ::= " + rhs.map{|gs| gs.inspect}.join(" ")
    end

  end
end  

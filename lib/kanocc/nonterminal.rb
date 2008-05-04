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
require 'kanocc/grammar_rule'
module Kanocc
  class Nonterminal
    attr_accessor :start_pos, :end_pos
    @@rules = Hash.new
    @@lastRule = Hash.new
    @@derivesRight = Hash.new
    @@operatorPrecedence = Hash.new
    @@methodNames = Hash.new
    
    Left = 1
    Right = 2
        
    def Nonterminal.derives_right
      @@derivesRight[self] = true
    end
    
    def Nonterminal.derives_right?
      return @@derivesRight[self]
    end
   
    def Nonterminal.set_operator_precedence(operator, precedence) 
      raise "Precedence must be an integer" unless precedence.class == Fixnum
      @@operatorPrecedence[self] ||= Hash.new 
      if is_an_operator?(operator)
        @@operatorPrecedence[self][operator] = precedence
      elsif is_an_array_of_operators(operator)
        operator.each {|o| @@operatorPrecedence[self][o] = precedence}
      else
        raise "Operator must be a string, a token or an array of those"  
      end 
    end
 
    def Nonterminal.operator_precedence(operator)
      (@@operatorPrecedence[self] and @@operatorPrecedence[self][operator]) or 0
    end

    def Nonterminal.is_an_array_of_operators(arr) 
       arr.is_a?(Array) and
       arr.collect{|o| is_an_operator?(o)}.inject {|b1, b2| b1 and b2 }
    end
    
    def Nonterminal.is_an_operator?(operator)
        operator.is_a?(String) or operator.is_a?(Token) 
    end

    def Nonterminal.rules
      rules = @@rules[self] 
      return rules ? rules : []
    end
    
    def Nonterminal.add_rule(rule)
      @@rules[self] ||= []
      @@rules[self].push(rule)
      @@lastRule[self] = rule
    end
    
    def Nonterminal.is_a_grammarsymbol?(x) 
      x.is_a?(String) or (x.respond_to?("is_a_kanocc_grammarsymbol?") and x.is_a_kanocc_grammarsymbol?)
    end

    def Nonterminal.is_a_kanocc_grammarsymbol? 
      return true 
    end
 
    def Nonterminal.rule(*rhs, &block)
      for pos in 0..rhs.length - 1 do
        unless is_a_grammarsymbol?(rhs[pos])
          raise "Problem with rule: #{rhs.inspect}, element:#{pos.to_s} - #{rhs[pos].inspect}\nElements of a rule must be Strings, Tokens or Nonterminals"
        end
      end
           
      if block_given?
        method_name = generate_method_name(*rhs) 
        define_method(method_name.to_sym, &block)
        add_rule(GrammarRule.new(self, rhs, method_name.to_sym))
      else
        add_rule(GrammarRule.new(self, rhs, nil))
      end
    end
  
    def Nonterminal.zm(symbols, sep = nil)
      list_class = new_list_class 
      list_class.rule() {@elements = []}
      list_class.rule(om(symbols, sep)) {@elements = @rhs[0].elements}
      return list_class
    end
    
    def Nonterminal.om(symbols, sep = nil)
      symbols = [symbols] unless symbols.is_a? Array
      list_class = new_list_class
      list_class.rule(*symbols) {@elements = @rhs}
      if sep
        list_class.rule(list_class, sep, *symbols) {@elements = @rhs[0].elements + @rhs[2..@rhs.length]}
      else
        list_class.rule(list_class, *symbols) {@elements = @rhs[0].elements + @rhs[1..@rhs.length]}
      end
      return list_class
    end
    
    @@listClassNumber = 0
 
    def Nonterminal.new_list_class
      list_class = Class.new(List)
      @@listClassNumber += 1
      def list_class.inspect
        return "anonList_#{@@listClassNumber}"
      end
      return list_class
    end

    def Nonterminal.generate_method_name(*args)
      method_name = self.name + " --> " + args.map {|a| a.inspect}.join(' ')
      @@methodNames[self] ||= []
      i = 1
      while @@methodNames[self].member?(method_name) do 
        method_name += ' ';
      end
      @@methodNames[self].push(method_name)
      return method_name
    end
  
    def Nonterminal.prec(p) 
      raise "Call to prec not preceded by rule" unless @@lastRule[self]
      @@lastRule[self].prec = p
    end
    
    def Nonterminal.show_method_names
      @@methodNames[self].each{|mn| puts mn.inspect} if @@methodNames[self]
    end
  end
  
  
  class List < Nonterminal
    attr_reader :elements
    
        protected
    # Assumes @rhs[0] is a Kanocc::List and that rhs.length > 1
    def collect(strip_separator = false)
      puts "collect with stripSeparator = #{strip_separator}"
      @elements = @rhs[0].elements
      if strip_separator
        @elements = @elements + @rhs[2..@rhs.length]
      else
        @elements = @elements + @rhs[1..@rhs.length]
      end
      puts "@elements: " + @elements.inspect
    end
  end

  class Error < Nonterminal
    attr_reader :text
    def initialize
      super
      @text = "FIXME"
    end
  end
end

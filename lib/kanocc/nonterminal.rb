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
    attr_accessor :startPos, :endPos
    @@rules = Hash.new
    @@lastRule = Hash.new
    @@derivesRight = Hash.new
    @@operatorPrecedence = Hash.new
    @@methodNames = Hash.new
    
    Left = 1
    Right = 2
        
    def Nonterminal.derivesRight
      @@derivesRight[self] = true
    end
    
    def Nonterminal.derivesRight?
      return @@derivesRight[self]
    end
   
    def Nonterminal.setOperatorPrecedence(operator, precedence) 
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
 
    def Nonterminal.operatorPrecedence(operator)
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
    
    def Nonterminal.addRule(rule)
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
        methodName = generateMethodName(*rhs) 
        define_method(methodName.to_sym, &block)
        addRule(GrammarRule.new(self, rhs, methodName.to_sym))
      else
        addRule(GrammarRule.new(self, rhs, nil))
      end
    end
  
    def Nonterminal.zm(symbols, sep = nil)
      listClass = newListClass 
      listClass.rule() {@elements = []}
      listClass.rule(om(symbols, sep)) {@elements = @rhs[0].elements}
      return listClass
    end
    
    def Nonterminal.om(symbols, sep = nil)
      symbols = [symbols] unless symbols.is_a? Array
      listClass = newListClass
      listClass.rule(*symbols) {@elements = @rhs}
      if sep
        listClass.rule(listClass, sep, *symbols) {@elements = @rhs[0].elements + @rhs[2..@rhs.length]}
      else
        listClass.rule(listClass, *symbols) {@elements = @rhs[0].elements + @rhs[1..@rhs.length]}
      end
      return listClass
    end
    
    @@listClassNumber = 0
 
    def Nonterminal.newListClass
      listClass = Class.new(List)
      @@listClassNumber += 1
      def listClass.inspect
        return "anonList_#{@@listClassNumber}"
      end
      return listClass
    end

    def Nonterminal.generateMethodName(*args)
      methodName = self.name + " --> " + args.map {|a| a.inspect}.join(' ')
      @@methodNames[self] ||= []
      i = 1
      while @@methodNames[self].member?(methodName) do 
        methodName += ' ';
      end
      @@methodNames[self].push(methodName)
      return methodName
    end
  
    def Nonterminal.prec(p) 
      raise "Call to prec not preceded by rule" unless @@lastRule[self]
      @@lastRule[self].prec = p
    end
    
    def Nonterminal.showMethodNames
      @@methodNames[self].each{|mn| puts mn.inspect} if @@methodNames[self]
    end
  end
  
  
  class List < Nonterminal
    attr_reader :elements
    
        protected
    # Assumes @rhs[0] is a Kanocc::List and that rhs.length > 1
    def collect(stripSeparator = false)
      puts "collect with stripSeparator = #{stripSeparator}"
      @elements = @rhs[0].elements
      if stripSeparator
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

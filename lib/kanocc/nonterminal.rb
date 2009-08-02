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
require 'ruby-debug'
module Kanocc
  class Nonterminal
    @@rules = Hash.new
    @@last_rule = Hash.new
    @@bind_right = Hash.new
    @@method_names = Hash.new
    
    Left = 1
    Right = 2
        
    def Nonterminal.rules
      rules = @@rules[self] 
      return rules ? rules : []
    end
    
    def Nonterminal.add_rule(rule)
      @@rules[self] ||= []
      @@rules[self].push(rule)
      @@last_rule[self] = rule
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
      if sep
        list_class.rule(list_class, sep, *symbols) {@elements = @rhs[0].elements + @rhs[2..@rhs.length]}
      else
        list_class.rule(list_class, *symbols) {@elements = @rhs[0].elements + @rhs[1..@rhs.length]}
      end
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
      @@method_names[self] ||= []
      i = 1
      while @@method_names[self].member?(method_name) do 
        method_name += ' ';
      end
      @@method_names[self].push(method_name)
      return method_name
    end

    def Nonterminal.precedence(prec)
      raise "Given rule precedence was not a Numeric" unless prec.is_a? Numeric
      raise "Call to precedence must be preceded by a rule" unless @@last_rule[self]
      @@last_rule[self].precedence = prec
    end

    def Nonterminal.derives_right
      raise "Call to derives_right must be preceded by a rule" unless @@last_rule[self]
      @@last_rule[self].derives_right = true
    end
    
    def Nonterminal.show_method_names
      @@method_names[self].each{|mn| puts mn.inspect} if @@method_names[self]
    end

    def inspect
      self.class.name  
    end

    def Nonterminal.show_rules
      rules.each do |rule| 
	puts rule.inspect
      end
    end
    
    def Nonterminal.show_all_rules
       queue = [self]
       done = {}
       i = 0
       while (i < queue.length)
	 queue[i].show_rules
	 done[queue[i]] = true
         queue[i].rules.each do |rule|
	   rule.rhs.each do |gs|
	     if gs.respond_to?(:rules) and not done[gs]
	       queue.push(gs)
             end
           end
         end
	 i += 1
       end
    end
  end
  
  
  class List < Nonterminal
    attr_reader :elements
    
        protected
    # Assumes @rhs[0] is a Kanocc::List and that rhs.length > 1
    def collect(strip_separator = false)
      @elements = @rhs[0].elements
      if strip_separator
        @elements = @elements + @rhs[2..@rhs.length]
      else
        @elements = @elements + @rhs[1..@rhs.length]
      end
    end
  end

  class Error < Nonterminal
    def str 
      "hey" # FIXME
    end
  end

  class StartSymbol < Nonterminal
  end
end

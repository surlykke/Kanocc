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
require 'kanocc/token'
require 'logger'
module Kanocc
  #
  # Parser for Kanocc based on Earleys algorithm. For a description see:
  # Alfred V. Aho, Jeffrey D. Ullman, The Theory of Parsing, Translation and  Compiling, 
  # or try a web search engine of your choice with 'Earley parsing'
  #
  # Earley's parser will parse according to any zcontext-free grammar using O(n*n*n) time 
  # and O(n*n) space, n being the length of input. If the grammar is unambigous time/space 
  # complexity is O(n*n)/O(n*n).
  # As of yet (version 0.1) the implementation is surely not optimal, 
  # so time/space complexity is probably worse.
  #
  # Christian Surlykke 2007.
  #
  class EarleyParser
    attr_accessor :kanocc, :logger
    
    ErrorRule = GrammarRule.new(Error, [], nil)
    
    def initialize(kanocc, options = {})
      @kanocc = kanocc
      @logger = options[:logger] || Logger.new
    end

    #
    # Sets up the parser, creating itemlist 0.
    #
    def startsymbol=(startSymbol)
      @start_symbol = startSymbol
      @itemLists = [ItemList.new(nil, 0, 0)]
      @inputPos = 0
      @recoveryPoints = []
      @itemLists[0].add_all(@start_symbol.rules.map{|rule| Item.new(rule, 0)})
      predict_and_complete(0)
    end
    
    def prepare
      @itemLists = @itemLists[0..0]
      @inputPos = 0
      if @recoveryPoints.size > 0 and @recoveryPoints[0] == 0
        @recoveryPoints = [0]
      else
        @recoveryPoints = []
      end
      @logger.info("Itemlist 0:\n" + @itemLists[0].inspect) unless not @logger
    end

    def scan(terminals) 
      terminals.each do |terminal| 
        @itemLists[@inputPos].add_all(@itemLists[@inputPos - 1].find_matching(terminal).map{|item| item.move})
      end
    end
    
    def predict_and_complete(pos)
      item_list = @itemLists[pos] 
      prev_size = 0      
      while prev_size < item_list.size do 
        prev_size = item_list.size	
	item_list.each do |item|
	  if item.rule.rhs.length <= item.dot
            # complete 
	    item_list.add_all(@itemLists[item.j].find_matching(item.rule.lhs).map{|item| item.move})
          elsif (nont = item.rule.rhs[item.dot]).respond_to?(:rules)  
            # predict
	    item_list.add_all(nont.rules.map {|rule| Item.new(rule, @inputPos)})
	  end
        end
      end 
    end
    
    def add_recovery_points(pos)
      if @recoveryPoints[-1] != pos
	@itemLists[pos].each do |item| 
	  if Error == item.rule.rhs[item.dot]
	    @recoveryPoints.push(pos)
	    break
	  end
	end
      end
    end

    #
    # Consume and parse next input symbol
    #
    def consume(inputSymbols, startPos, endPos) 
      @inputPos += 1
      @itemLists.push(ItemList.new(inputSymbols, @inputPos, endPos))
  
      # scan, predict and complete until no more can be added
      scan(inputSymbols)
      
      if @itemLists[@inputPos].size == 0
        @logger.debug("Found no items matching #{inputSymbols} in itemlist #{@inputPos - 1}")
        @logger.debug("@recoveryPoints = " + @recoveryPoints.inspect)	
        for i in 1..@recoveryPoints.length do 
          if @recoveryPoints[-i] < @inputPos
            @itemLists[@inputPos - 1].add(Item.new(ErrorRule, @recoveryPoints[-i]))
            predict_and_complete(@inputPos - 1) 
	    scan(inputSymbols) 
	    break if @itemLists[@inputPos].size > 0 
          end
        end
      end
      predict_and_complete(@inputPos) 
      add_recovery_points(@inputPos)
      @logger.info("Itemlist #{@inputPos}:\n" + @itemLists[@inputPos].inspect) if @logger
    end
   
    
    #
    # Signal to the parser that end of input is reached
    #
    def eof
      @logger.debug "--- Parsing done, translating ---"
      top_item = find_full_items(@start_symbol, @inputPos).find_all {|item| item.j == 0}.min
      if top_item 
        translate(top_item, @inputPos)
      else
        raise(KanoccException, "It didn't parse")
      end
    end
    
    def translate(element, pos)
      @logger.debug("translate: " + element.inspect + ", pos = " + pos.inspect)   
      if element.class == Item
        translate_helper(element, pos) 
        @kanocc.report_reduction(element.rule, 
                                @itemLists[element.j].textPos, 
                                @itemLists[pos].textPos)
      elsif element.class == Class # Its a token class
	@kanocc.report_token(@itemLists[pos].inputSymbol.find {|sym| sym.is_a? element})
      else # Its a string instance
        @logger.debug @itemLists[pos].inspect
        @kanocc.report_token(element)
      end
    end
    
    def translate_helper(item, pos)
      @logger.debug("translateHelper: " + item.inspect) 
      return if item.dot == 0 
      if item.rule.rhs[item.dot - 1].respond_to?("rules")
        # Assume item is of form [A --> aB*c, k] in itemlist i
        # Must then find item of form [B --> x*, j] in itemlist i so 
        # that there exists item of form [A --> a*Bc, k] on itemlist j
        
        # First: Items of form [B --> x*, j] on list i 
        candidates = find_full_items(item.rule.rhs[item.dot - 1], pos)
        
        # Then: Those for which item of form [A --> a*Bc, k] exists
        # on list j
        candidates = candidates.find_all {|subItem|
          @itemLists[subItem.j].find_item(item.rule, item.dot - 1, item.j)
        }
        ##### 
        # Precedence handling is somewhat problematic in Earley parsing. 
        # We now have to choose amongst possibly several candidates
        #
        # Last: Pick the one with the rule with the _lowest_ precedence
        # (We are finding reductions top-down, but will evaluate bottom-up, hence
        # this will make the rule with the _highest_ precedence evaluate first.
        
        
        sub_item = candidates.min
        prev_item = @itemLists[sub_item.j].find_item(item.rule, item.dot - 1, item.j)
        prev_list = sub_item.j
      else
        prev_item = @itemLists[pos - 1].find_item(item.rule, item.dot - 1, item.j)
        prev_list = pos - 1
        sub_item = item.rule.rhs[item.dot - 1]
      end
      translate_helper(prev_item, prev_list)
      translate(sub_item, pos)
    end
        
    def find_full_items(nonterminal, inputPos)
      @itemLists[inputPos].find_all do |item|
        item.rule.lhs == nonterminal and item.dot >= item.rule.rhs.length
      end
    end
    
    def operator_precedence(rule)
      - (@kanocc.operator_precedence(rule))
    end
  end 
  
  class ItemList
    attr_reader :inputSymbol, :textPos
    attr_accessor :items
    
    def initialize(inputSymbol, inputPos, textPos)
      @inputPos = inputPos
      @inputSymbol = inputSymbol
      @textPos = textPos
      @items = Hash.new 
    end
    
    def copy
      res = clone
      res.items = @items.clone
      return res
    end
    
    def size
      return @items.size
    end
    
    def find_all(&b)
      return @items.keys.find_all(&b)
    end
    
    def find_item(rule, dot, j)
      return @items.keys.find{ |item| 
        item.rule == rule and 
        item.dot == dot and
        item.j == j
      }
    end
    
    def each_matching(inputSymbol)
      find_matching(inputSymbol).each do |item| 
        yield(item)
      end
    end
    
    def find_matching(inputSymbol)
      @items.keys.find_all do |item| 
        inputSymbol === item.symbol_after_dot or inputSymbol == item.symbol_after_dot
      end
    end
    
    def contains(item)
      return @items[item]
    end
    
    def add(item)
      @items.store(item, true)
    end
    
    def add_all(items)
      items.each {|item| @items.store(item, true)}
    end

    def each
      @items.keys.each do |item|
        yield item
      end
    end
    
    def inspect
      return "[" + @inputSymbol.inspect + "\n " + 
                   @textPos.to_s + "\n " +
                   @items.keys.map{|item| item.inspect}.join("\n  ") + "]\n" 
    end
  end
  
  
  class Item
    attr_reader :rule, :j, :dot
    @@items = Hash.new
    
    def Item.new(rule, j, dot = 0)
      unless (item = @@items[[rule,j,dot]])
        item = super(rule, j, dot)
        @@items.store([rule, j, dot], item)
      end
      return item
    end
    
    def symbol_after_dot
      return @dot < @rule.rhs.size  ? @rule.rhs[@dot] : nil
    end
    
    def initialize(rule, j, dot = 0)
      @rule = rule
      @j = j
      @dot = dot
    end
    
    def move
      return Item.new(@rule, @j, @dot + 1)
    end
    
    def inspect
      return "[" + 
      @rule.lhs.inspect + " --> " + 
       (@rule.rhs.slice(0, dot) + 
      [Dot.new] + 
      @rule.rhs.slice(dot, @rule.rhs.length - dot)).map{|symbol| symbol.inspect}.join(" ") + 
              " ; " + @j.to_s + "]"
    end
  
    def <=>(other)
      tmp = (@rule.prec <=> other.rule.prec)
      if tmp == 0
        return other.j <=> @j
      else 
        return tmp
      end
    end
  end
  
  # Just for Item inspect
  class Dot
    def inspect
      return "*"
    end
  end
end

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
    def startSymbol=(startSymbol)
      @startSymbol = startSymbol
      @itemLists = [ItemList.new(nil, 0, 0)]
      @inputPos = 0
      @recoveryPoints = []
      @itemLists[0].addAll(@startSymbol.rules.map{|rule| Item.new(rule, 0)})
      predictAndComplete(0)
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
        @itemLists[@inputPos].addAll(@itemLists[@inputPos - 1].findMatching(terminal).map{|item| item.move})
      end
    end
    
    def predictAndComplete(pos)
      itemList = @itemLists[pos] 
      prevSize = 0      
      while prevSize < itemList.size do 
        prevSize = itemList.size	
	itemList.each do |item|
	  if item.rule.rhs.length <= item.dot
            # complete 
	    itemList.addAll(@itemLists[item.j].findMatching(item.rule.lhs).map{|item| item.move})
          elsif (nont = item.rule.rhs[item.dot]).respond_to?(:rules)  
            # predict
	    itemList.addAll(nont.rules.map {|rule| Item.new(rule, @inputPos)})
	  end
        end
      end 
    end
    
    def addRecoveryPoints(pos)
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
            predictAndComplete(@inputPos - 1) 
	    scan(inputSymbols) 
	    break if @itemLists[@inputPos].size > 0 
          end
        end
      end
      predictAndComplete(@inputPos) 
      addRecoveryPoints(@inputPos)
      @logger.info("Itemlist #{@inputPos}:\n" + @itemLists[@inputPos].inspect) if @logger
    end
   
    
    #
    # Signal to the parser that end of input is reached
    #
    def eof
      @logger.debug "--- Parsing done, translating ---"
      topItem = findFullItems(@startSymbol, @inputPos).find_all {|item| item.j == 0}.min
      if topItem 
        translate(topItem, @inputPos)
      else
        raise(KanoccException, "It didn't parse")
      end
    end
    
    def translate(element, pos)
      @logger.debug("translate: " + element.inspect + ", pos = " + pos.inspect)   
      if element.class == Item
        translateHelper(element, pos) 
        @kanocc.reportReduction(element.rule, 
                                @itemLists[element.j].textPos, 
                                @itemLists[pos].textPos)
      elsif element.class == Class # Its a token class
	@kanocc.reportToken(@itemLists[pos].inputSymbol.find {|sym| sym.is_a? element})
      else # Its a string instance
        @logger.debug @itemLists[pos].inspect
        @kanocc.reportToken(element)
      end
    end
    
    def translateHelper(item, pos)
      @logger.debug("translateHelper: " + item.inspect) 
      return if item.dot == 0 
      if item.rule.rhs[item.dot - 1].respond_to?("rules")
        # Assume item is of form [A --> aB*c, k] in itemlist i
        # Must then find item of form [B --> x*, j] in itemlist i so 
        # that there exists item of form [A --> a*Bc, k] on itemlist j
        
        # First: Items of form [B --> x*, j] on list i 
        candidates = findFullItems(item.rule.rhs[item.dot - 1], pos)
        
        # Then: Those for which item of form [A --> a*Bc, k] exists
        # on list j
        candidates = candidates.find_all {|subItem|
          @itemLists[subItem.j].findItem(item.rule, item.dot - 1, item.j)
        }
        ##### 
        # Precedence handling is somewhat problematic in Earley parsing. 
        # We now have to choose amongst possibly several candidates
        #
        # Last: Pick the one with the rule with the _lowest_ precedence
        # (We are finding reductions top-down, but will evaluate bottom-up, hence
        # this will make the rule with the _highest_ precedence evaluate first.
        
        
        subItem = candidates.min
        prevItem = @itemLists[subItem.j].findItem(item.rule, item.dot - 1, item.j)
        prevList = subItem.j
      else
        prevItem = @itemLists[pos - 1].findItem(item.rule, item.dot - 1, item.j)
        prevList = pos - 1
        subItem = item.rule.rhs[item.dot - 1]
      end
      translateHelper(prevItem, prevList)
      translate(subItem, pos)
    end
        
    def findFullItems(nonterminal, inputPos)
      @itemLists[inputPos].find_all do |item|
        item.rule.lhs == nonterminal and item.dot >= item.rule.rhs.length
      end
    end
    
    def operatorPrecedence(rule)
      - (@kanocc.operatorPrecedence(rule))
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
    
    def findItem(rule, dot, j)
      return @items.keys.find{ |item| 
        item.rule == rule and 
        item.dot == dot and
        item.j == j
      }
    end
    
    def eachMatching(inputSymbol)
      findMatching(inputSymbol).each do |item| 
        yield(item)
      end
    end
    
    def findMatching(inputSymbol)
      @items.keys.find_all do |item| 
        inputSymbol === item.symbolAfterDot or inputSymbol == item.symbolAfterDot
      end
    end
    
    def contains(item)
      return @items[item]
    end
    
    def add(item)
      @items.store(item, true)
    end
    
    def addAll(items)
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
    
    def symbolAfterDot
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

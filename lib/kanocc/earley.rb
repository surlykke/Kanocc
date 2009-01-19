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

require 'rubygems'
require 'ruby-debug'
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
      @scanner = Scanner.new
      self.logger = options[:logger] || Logger.new
    end

    def logger=(logger)
      @logger = logger
      @scanner.logger = @logger
    end
    #
    # Sets up the parser, creating itemlist 0.
    #
    def start_symbol=(startSymbol)   
      @scanner.set_recognized(*(@kanocc.find_tokens(startSymbol)))
      @start_symbol = startSymbol
      @itemLists = [ItemList.new(0)]
      @inputPos = 0
      @recoveryPoints = []
      @itemLists[0].add_all(@start_symbol.rules.map{|rule| Item.new(rule, 0)})
      predict_and_complete(0)
    end
    
    def set_whitespace(*ws)
      @scanner.set_whitespace(*ws)
    end
    
    def parse(input)
      @scanner.input = input 
      prepare	
      
      while (@scanner.next_match!) do
        @inputPos += 1
        @itemLists.push(ItemList.new(@inputPos))
    
        # scan, predict and complete until no more can be added
        consume_token
        predict_and_complete(@inputPos) 
        @logger.debug("@itemLists[#{@inputPos}]: " + @itemLists[@inputPos].inspect) 
	handle_error if @itemLists[@inputPos].size == 0 
      end
     
      for i in 0..@inputPos do
        @logger.info("\n" + @itemLists[i].inspect)
      end
 
      top_item = find_full_items(@start_symbol, @inputPos).find_all {|item| item.j == 0}.max
      if top_item 
        translate(top_item, @inputPos)
      else
        raise(KanoccException, "It didn't parse")
      end
    end

    def prepare
      @itemLists = @itemLists[0..0]
      @inputPos = 0
      if @recoveryPoints.size > 0 and @recoveryPoints[0] == 0
        @recoveryPoints = [0]
      else
        @recoveryPoints = []
      end
      @logger.info("Itemlist 0:\n" + @itemLists[0].inspect) if @logger
    end

    def consume_token 
      @itemLists[@inputPos].inputSymbol = @scanner.current_match
      @scanner.current_match[:matches].each do |match| 
	if match[:token] 
	  symbol = match[:token]
        else
          symbol = match[:literal]
        end
        @itemLists[@inputPos - 1].each do |item| 
          if symbol === item.symbol_after_dot or symbol == item.symbol_after_dot	  
	    @itemLists[@inputPos].add(item.move)
          end
        end
      end
    end
    
    def predict_and_complete(pos, show=false)
      item_list = @itemLists[pos] 
      prev_size = 0      
      while prev_size < item_list.size do 
        prev_size = item_list.size	
	item_list.each do |item|
	  if item.rule.rhs.length <= item.dot
            # complete 
            newItems = @itemLists[item.j].find_matching(item.rule.lhs).map{|item| item.move}
            item_list.add_all(newItems)
          elsif (nont = item.rule.rhs[item.dot]).respond_to?(:rules)  
            # predict
            newItems = nont.rules.map {|rule| Item.new(rule, pos)}
	    item_list.add_all(newItems)
	  end
        end
      end 
    end
       
    def handle_error
         
      if j = find_error_items() 
        @itemLists[@inputPos - 1].add(Item.new(ErrorRule, j)) 
        predict_and_complete(@inputPos - 1, true)
 	consume_token
	predict_and_complete(@inputPos)
        @logger.info("Itemlist #{@inputPos} after error handling:\n" + 
	             @itemLists[@inputPos].inspect) if @logger
      end
    end

    def find_error_items
      for i in (@inputPos - 1).downto(0) do
        return i if @itemLists[i].items.keys.find {|item| item.rule.rhs[item.dot] == Error }
      end
      return nil
    end

    def create_error_item(j)
      rule = Error.rules[0]
      return Item.new(rule, j, 0)
    end

    def report_parsing_error(token_match)
         expectedTerminals = 
	  @itemLists[@inputPos - 1].map { |item| item.rule.rhs[item.dot]}.find_all do |gs|
	    gs.is_a? String or (gs.is_a? Class and gs.ancestors.include?(Token))
          end.uniq
	        
	errorMsg = "Could not consume input: #{token_match[:string].inspect}" +
                   " at position: #{token_match[:start_pos].inspect}"
	if expectedTerminals.size > 0
	  errorMsg += " - expected " +
	              "#{expectedTerminals.map {|t| t.inspect}.join(" or ")}" 
        else 
          errorMsg += " - no input could be consumed at this point." 
        end
	
        raise ParseException.new(errorMsg, 
	                         token_match[:string], 
			         expectedTerminals,
			         token_match[:start_pos])

    end 


    #
    # Signal to the parser that end of input is reached
    #
    def eof
    end
    
    def translate(element, pos)
      @logger.debug("translate: " + element.inspect + " on " + pos.inspect)   
      if element.class == Item
        translate_helper(element, pos) 
        @kanocc.report_reduction(element.rule)
      else  # Its a token or a string
	@kanocc.report_token(@itemLists[pos].inputSymbol, element)
      end
    end
    
    def translate_helper(item, pos)
      @logger.debug("translateHelper: " + item.inspect + " on " + pos.inspect) 
      return if item.dot == 0
      if item.rule.rhs[item.dot - 1].respond_to?("rules")  
        # Assume item is of form [A --> aB*c, k] in itemlist i
        # Must then find item of form [B --> x*, j] in itemlist i so 
        # that there exists item of form [A --> a*Bc, k] on itemlist j
        
        # First: Items of form [B --> x*, j] on list i 
        candidates = find_full_items(item.rule.rhs[item.dot - 1], pos)
        
        # Then: Those for which item of form [A --> a*Bc, k] exists
        # on list j
	@logger.debug("thinning candidates, which are: " + candidates.inspect)
        candidates = candidates.find_all {|subItem|
          @itemLists[subItem.j].find_item(item.rule, item.dot - 1, item.j)
        }
        
        # Precedence: We pick the posibility with the higest precedence
        sub_item = candidates.max
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
  end 
  
  class ItemList
    attr_accessor :inputSymbol
    attr_accessor :items
    
    def initialize(inputPos)
      @inputPos = inputPos
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
   
    def map(&b)
      return @items.keys.map(&b)
    end

    def find_item(rule, dot, j)
      res =  @items.keys.find{ |item| 
        item.rule == rule and 
        item.dot == dot and
        item.j == j
      }
      return res
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
      items.each {|item| add(item)}
    end

    def each
      @items.keys.each do |item|
        yield item
      end
    end
    
    def inspect
      return "[" + (@inputSymbol ? @inputSymbol[:string] : nil).inspect + "\n " + 
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
      res = @rule.prec <=> other.rule.prec;
      if res == 0 and @rule.operator_prec and other.rule.operator_prec 
	res = other.rule.operator_prec <=> @rule.operator_prec
      end
      if res == 0
        res = @j <=> other.j 
      end
      return res
    end
  end
  
  # Just for Item inspect
  class Dot
    def inspect
      return "*"
    end
  end
end

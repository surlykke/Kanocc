## 
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
require 'kanocc/nonterminal'
require 'kanocc/token'
require 'logger'

#require 'rubygems'

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
    
    def initialize(kanocc, logger)
      @kanocc = kanocc
      @logger = logger
    end
    
    def start_symbol=(start_symbol)   
      @start_symbol = Class.new(StartSymbol) do
        def self.to_s
         "S'"
        end
        rule(start_symbol)
      end 
    end
    

    def parse(scanner)
      @scanner = scanner
      prepare
      
     while (@scanner.next_match!) do
        @inputPos += 1
        @input_symbols.push(scanner.current_match)
        @items.prepare_for_n(@inputPos)
        # scan, predict and complete until no more can be added

        scan

        predict_and_complete(@inputPos)

        if @logger
          @logger.info("\nItems at #{@inputPos}:\n" +
                       @input_symbols[@inputPos].inspect + "\n" +
                       @items.items_at_n(@inputPos).map{|item| " " + item.inspect}.join("\n") + "\n")
        end

        handle_error if @items.number_at_n(@inputPos) == 0
      end

      reduce
    end
    
    def prepare
      @items = ItemSet.new
      @inputPos = 0
      @input_symbols = [nil]
      @recoveryPoints = []
      @start_symbol.rules.each do |rule|
        @items.add(rule, 0, 0, 0, -1)
      end
      predict_and_complete(0)
      if @logger
        @logger.info("\nItems at 0:\n" +
                     @items.items_at_n(0).map{|item| " " + item.inspect}.join("\n") + "\n")
      end
    end
    
    # Scan: At position n, for each terminal a in current match, and each item
    # of form [A -> x*ay, i, n-1], add [A -> xa*y, i, n]
    def scan

      @scanner.current_match.terminals.each do |terminal|
        @items.items_n_and_symbol_after_dot(@inputPos -1, terminal).each do |item|
           @items.add(item.rule, item.dot + 1, item.j, @inputPos,  @inputPos - 1)
        end
      end

    end


    # Predict: For any item of form [A -> a*Bb, j, n] and for all rules of form
    # B -> c, add [B -> *c, n, n].
    #
    # Complete: Given an item of form [A->X*, j, n], find all items of form
    # [B -> a*Ab, i, j], and add [B -> aA*b, i, n].
    #
    # Predict and complete until nothing further can be added.
    def predict_and_complete(pos, show=false)
      prev_size = 0
      while true do
        break if prev_size >= @items.number_at_n(pos)
        prev_size = @items.number_at_n(pos)
        @items.items_at_n(pos).each do |item|
          if item.dot >= item.rule.rhs.length
            # complete
            @items.items_n_and_symbol_after_dot(item.j, item.rule.lhs).each do |previtem|
              @items.add(previtem.rule, previtem.dot + 1, previtem.j, pos, item.j)
            end
          elsif item.rule.rhs[item.dot].respond_to?(:rules)
            # predict
            item.rule.rhs[item.dot].rules.each do |rule|
              @items.add(rule, 0, pos, pos, -1)
            end
          end
        end
      end
    end
    
    def handle_error
      if j = find_error_items()
        @items.add(ErrorRule, 0, j, @inputPos - 1, -1)
        predict_and_complete(@inputPos - 1, true)
        if @logger
	  @logger.info("Items at #{@inputPos - 1} after error handling:\n" + 
	               @items.items_at_n(@inputPos - 1).map {|item| item.inspect}.join("\n"))
	end
	scan
        predict_and_complete(@inputPos)
        if @logger
          @logger.info("Items at #{@inputPos} after error handling:\n" +
                       @items.items_at_n(@inputPos).map {|item| item.inspect}.join("\n"))
        end
      end
    end

    def find_error_items
      for n in (@inputPos - 1).downto(0) do
        if @items.items_n_and_symbol_after_dot(n, Error).size > 0
          return n
        end
      end
      return nil
    end

    def report_parsing_error(token_match)
      expected_terminals =
        @items.items_at_n(@inputPos - 1).map { |item| item.rule.rhs[item.dot]}.find_all do |gs|
          gs.is_a? String or (gs.is_a? Class and gs.ancestors.include?(Token))
        end.uniq

      error_msg = "Could not consume input: #{token_match[:string].inspect}" +
                 " at position: #{token_match[:start_pos].inspect}"
      if expected_terminals.size > 0
        error_msg += " - expected " +
                     "#{expected_terminals.map {|t| t.inspect}.join(" or ")}"
      else
        error_msg += " - no input could be consumed at this point."
      end

      raise ParseException.new(error_msg,
                               token_match[:string],
                               expected_terminals,
                               token_match[:start_pos])

    end
      
    def reduce
      item = @items.items_at_n(@inputPos).find do |item|
        @start_symbol == item.rule.lhs and item.dot == 1
      end
      if item
        # There is at most one of those
        make_parse(item, @inputPos, 0)
      else
        raise(KanoccException, "It didn't parse")
      end
    end

    # FIXME Generates stack overflow when files are large.
    #  15000-2000 inputsymbols with the calculator syntax.
    # Should be rewritten to something non-recursive
    def make_parse(item, pos, prev_pos)
      return if item.dot <= 0

      prev_item = @items.find(item.rule, item.dot - 1, item.j, prev_pos)
      prev_prev_pos = prev_item.rule.derives_right ? prev_item.prev_pos_min : prev_item.prev_pos_max
      
      if is_nonterminal?(item.symbol_before_dot)
        subitem, sub_prev_pos = pick_subitem(item.symbol_before_dot, pos, prev_pos)
        make_parse(prev_item, prev_pos, prev_prev_pos)
        make_parse(subitem, pos, sub_prev_pos)
        @kanocc.report_reduction(subitem.rule)
      else
        make_parse(prev_item, prev_pos, prev_prev_pos)
        symbol = item.symbol_before_dot
        @kanocc.report_token(@input_symbols[pos], symbol)
      end
    end

    def pick_subitem(nonterminal, pos, prev_pos)
      #debugger
      items = @items.full_items_by_lhs_j_and_n(nonterminal, prev_pos, pos)

      raise "pick_subitem could not find any items" if items.size <= 0
      items = find_highest(items) {|item| precedence(item)}

      derives_right = all_derives_right(items)
      if derives_right
        items = find_highest(items) {|item| -item.prev_pos_min}
      else
        items = find_highest(items){|item| item.prev_pos_max}
      end

      return items[0], derives_right ? items[0].prev_pos_min : items[0].prev_pos_max
    end

    def find_highest(items, &expr)
      collect = []
      top_val = nil;
      items.each do |item|
        val = expr.call(item)
        if top_val == nil or top_val < val
          collect = [item]
          top_val = val
        elsif top_val == val
          collect << item
        end
      end
      return collect
    end

    def precedence(item)
      item.rule.precedence || 0
    end
      
    def all_derives_right(items)
      items.each do |item|
        return false unless item.rule.derives_right
      end
      return true
    end

    def is_nonterminal?(symbol)
      symbol.respond_to?(:rules)
    end
  end   
    
  class Item
    attr_reader :rule, :dot, :j, :n
    attr_accessor :prev_pos_min, :prev_pos_max

    def initialize(rule, dot, j, n,  prev_pos_min = 0, prev_pos_max = 0)
      @rule = rule
      @dot = dot
      @j = j
      @n = n
      @prev_pos_min = prev_pos_min
      @prev_pos_max = prev_pos_max
    end

    def symbol_after_dot
      return @dot < @rule.rhs.size  ? @rule.rhs[@dot] : nil
    end
    
    def symbol_before_dot
      return @dot > 0 ? @rule.rhs[@dot - 1] : nil
    end

    def set_prev_pos(new_prev_pos)
      if new_prev_pos < @prev_pos_min
        @prev_pos_min = new_prev_pos
      elsif new_prev_pos > @prev_pos_max
        @prev_pos_max = new_prev_pos
      end
    end
    
    def inspect
      return "[" + 
      @rule.lhs.inspect + " --> " + 
       (@rule.rhs.slice(0, dot) + [Dot.instance] +
      @rule.rhs.slice(dot, @rule.rhs.length - dot)).map{|symbol| symbol.inspect}.join(" ") + 
            " ; " + @j.inspect + ", " + @n.inspect + "]"
    end
  end
  

  class ItemSet
    # FIXME Optimize all this

    def initialize
      @item_lists = []
      @items_n_and_symbol_after_dot = {}
      @items_rule_dot_j_n = {}
    end

    def prepare_for_n(n)
      @item_lists[n] = []
    end

    def add(rule, dot, j, n, prev_pos)
      if item = @items_rule_dot_j_n[[rule,dot,j,n]]
        item.set_prev_pos(prev_pos)
      else
        item = Item.new(rule, dot, j, n, prev_pos, prev_pos)
        @items_rule_dot_j_n[[rule,dot,j,n]] = item
        @item_lists[item.n] = [] unless @item_lists[item.n]
        @item_lists[item.n] << item

        if item.symbol_after_dot
          unless @items_n_and_symbol_after_dot[[item.n, item.symbol_after_dot]]
            @items_n_and_symbol_after_dot[[item.n, item.symbol_after_dot]] = []
          end
          @items_n_and_symbol_after_dot[[item.n, item.symbol_after_dot]] << item
        end
      end
    end

    def find(rule, dot, j, n)
      @items_rule_dot_j_n[[rule, dot, j,n]]
    end

    def find_all_by_n(n)
      @item_lists[n].clone
    end

    def number_at_n(n)
      @item_lists[n].length
    end

    def items_n_and_symbol_after_dot(n, symbol)
      return @items_n_and_symbol_after_dot[[n, symbol]] || []
    end

    def full_items_by_lhs_j_and_n(lhs, j, n)
      @item_lists[n].find_all do |item|
        item.dot >= item.rule.rhs.size and
        item.j == j and
        item.rule.lhs == lhs
      end
    end

    def items_at_n(n)
      return @item_lists[n].clone
    end

  end

  # Just for Item inspect
  class Dot
    def Dot.instance
      @@instance
    end
    def inspect
      return "*"
    end
    @@instance = Dot.new
  end
end

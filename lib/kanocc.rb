# 
#  Kanocc - Kanocc ain't no compiler-compiler
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


require 'kanocc/token'
require 'kanocc/nonterminal'
require 'kanocc/scanner'
require 'kanocc/earley'
require 'logger'

# = Kanocc - Kanocc ain't no compiler-compiler
#
# Kanocc is a ruby-framework for parsing and translating.
# Emphasis is on easy, 'scripty' use, and seamless integration with ruby. Performance has been
# a secondary concern.
# In it's default configuration, Kanocc uses it's own lexical scanner and a parser 
# based on Earley's algorithm to allow handling of any context-free grammer. It is possible, 
# however, to plug in other lexical scanners or parsers. See ##FIXMEREF.
# 
# A simple example.
#
# Reading and evaluating reverse polish notated expressions. Consider this grammar:
#
#    E ::= E E '+' 
#        | E E '-'
#        | E E '*'
#        | E E '/'
#        | NUM
#
#    NUM a sequence of digits
#
# In Kanocc yout could do it like this:
#
#    require "kanocc"
#    
#    # ==========  Define a lexical grammar =============
#    class NUM < Kanocc::Token
#      attr_reader :val
#      set_pattern(/\d+/) { @val = @m[0].to_i}
#    end
#    
#    # ==========  Define a grammar ===================== 
#    class E < Kanocc::Nonterminal
#      attr_reader :val 
#      rule(E, E, "+") { @val = @rhs[0].val + @rhs[1].val} 
#      rule(E, E, "-") { @val = @rhs[0].val - @rhs[1].val}  
#      rule(E, E, "*") { @val = @rhs[0].val * @rhs[1].val} 
#      rule(E, E, "/") { @val = @rhs[0].val / @rhs[1].val} 
#      rule(NUM) { @val = @rhs[0].val }
#    end
#    
#    # ==========  Set up a parser ======================
#    myParser = Kanocc::Kanocc.new(E)
#    
#    # ==========  And try it out =======================
#    puts "3 4 + 2 - = #{myParser.parse("3 4 + 2 -").val}"
#    
# and you'd get:
#   
#    3 4 + 2 - = 5
#
# For more examples, please refer to the documentation: ##FIXMEREF
#
module Kanocc
  class Kanocc
    attr_accessor :scanner, :parser, :logger
    
    # Creates a new instance of Kannocc, with the given start symbol.
    # From the start_symbol, Kanocc will deduce the grammar and the 
    # grammarsymbols
    # 
    def initialize(start_symbol)
      @start_symbol = start_symbol 
      @logger = Logger.new(STDOUT)
      @logger.datetime_format = "" 
      @logger.level = Logger::WARN 
      @scanner = Scanner.new(:logger => @logger)
      @parser = EarleyParser.new(self, :logger => @logger)
    end
    
    def logger=(logger)
      @logger = logger || logger.new(STDOUT)
      @parser.logger = @logger if parser.respond_to?(:logger)
      @scanner.logger = @logger if scanner.respond_to?(:logger)
    end
  
    def parser=(parser)
      @parser = parser
      @parser.logger = @logger if parser.respond_to?(:logger=)
    end
    
    def scanner=(scanner)
      @scanner = scanner
      @scanner.logger = @logger if scanner.respond_to?(:logger=)
    end
    
    # Consume input. Kanocc will parse input according to the rules given, and
    # - if parsing succeeds - return an instance of the grammars start symbol.
    # Input may be a String or an IO object.
    def parse(input)
      raise "Start symbol not defined" unless @start_symbol
      tell_parser_start_symbol(@start_symbol) 
      @parser.prepare 
      @stack = []
      @inputPos = 0 
      @scanner.each_token(input) do |token_match|
        @logger.info "got #{token_match} from scanner"
        @inputPos += 1
        @parser.consume(token_match)
      end
      @parser.eof
      @stack[0]
    end
   
    def parse_file(file)
      if file.is_a? String # Then we assume it's a path	
	file = File.open(File.expand_path(file))
	opened_file = true
      end
      input = file.read
      file.close if opened_file
      parse(input)
    end
    
    # Define whitespace. By default, Kanocc will recogninze anything that matches 
    # /\s/ as whitespace. 
    # whitespace takes a variable number of arguments, each of which must be a 
    # regular expression.
    def set_whitespace(*ws)
      @scanner.set_whitespace(*ws)
    end
    
    # Define which tokens Kanocc should recognize. If this method is not called
    # Kanocc will scan for those tokens that are mentioned in the grammar.
    # tokens= takes a variable number of arguments. Each argument must either be
    # a string or a class which is a subclass of Kanocc::Token
    def set_tokens(*tokens)
      @scanner.set_recognized(*tokens)
    end
    
    # The parser must call this method when it have decided upon a reduction.
    # As arguments it should give the rule, by which to reduce. 
    def report_reduction(rule, start_pos, end_pos) 
      @logger.info "Reducing by " + rule.inspect
      nonterminal = rule.lhs.new      
      nonterminal.start_pos = start_pos
      nonterminal.end_pos = end_pos
      right_hand_side = @stack.slice!(-rule.rhs.length, rule.rhs.length)
      right_hand_side = right_hand_side.map {|e| e.is_a?(List) ? e.elements : e} unless nonterminal.is_a? List
      if rule.method
        old_rhs = nonterminal.instance_variable_get('@rhs')
        nonterminal.instance_variable_set('@rhs', right_hand_side)
        nonterminal.send(rule.method)
        nonterminal.instance_variable_set('@rhs', old_rhs)
      end
      @stack.push(nonterminal)
      show_stack
    end
    
   
    # The parser must call this method when it consumes a token
    # As argument it should give the consumed token and the positions 
    # in the input string corresponding to the token. Positions should be given
    # as the position of the first character of the token and the position of the 
    # first character after the token.
    def report_token(tokenmatch, element)
      @logger.info("Pushing token: " + element.inspect)
      matched_token = tokenmatch.tokens.find {|mt| mt == element}
      if matched_token.is_a? Class # It's a Token 
        token = matched_token.new(tokenmatch.string)
        token.m = token.match(tokenmatch.string)
        token.__recognize__ if token.respond_to?("__recognize__") 
      else # It's a string literal
        token = matched_token
      end
      @stack.push(token)
      show_stack 
    end
        
    
    def tell_parser_start_symbol(start_symbol)
      @parser.startsymbol = start_symbol
      bag_of_terminals = {}
      find_tokens(start_symbol, bag_of_terminals)
      @logger.debug "tokens = " + bag_of_terminals.keys.inspect 
      strings = bag_of_terminals.keys.find_all{|ter| ter.is_a? String} 
      @logger.info("Literals: " + strings.inspect)
      tokens = bag_of_terminals.keys.find_all{|ter| ter.is_a? Class and ter.ancestors.member?(Token)}
      @logger.info("Tokens: " + tokens.inspect)
      @scanner.set_recognized(*(strings + tokens))

      # Show rules
      @logger.info("Rules:")
      nonterminals = [start_symbol]
      nonterminals.each do |nonterminal|
        nonterminal.rules.each do |rule|
          @logger.info("  " + rule.inspect)
	  rule.rhs.each do |gs|
	    if gs.is_a? Class and gs.ancestors.member?(Nonterminal) and not nonterminals.member?(gs)
	      nonterminals.push(gs)
	    end
	  end
	end
      end
    end
    
    def find_tokens(nonterminal, collectedTokens,  visited_nonterminals = {})
      unless visited_nonterminals[nonterminal]
        visited_nonterminals[nonterminal] = true
        nonterminal.rules.each do |r| 
          r.rhs.each do |gs|
            if gs.is_a?(Class) and gs.ancestors.member?(Nonterminal)
              find_tokens(gs, collectedTokens, visited_nonterminals)
            else
              collectedTokens[gs] = true 
            end
          end
        end
      end
    end
        
    # For debugging
    def show_stack
      @logger.info("Stack: [" + @stack.map {|gs| show_grammar_symbol(gs)}.join(", ") + "]" ) if @logger
    end
    
    def show_grammar_symbols(tokens)
      "[" + tokens.map{|token| show_grammar_symbol(token)}.join(", ") + "]"
    end
    
    def show_grammar_symbol(gs) 
      if gs.is_a?(Nonterminal) or gs.is_a?(Token)
        gs.class.to_s; 
      else 
        gs
      end
    end
  
  end
  
  class TokenMatch
    attr_reader :tokens, :string, :start_pos, :length
    
    def initialize(tokens, string, start_pos, length)
      @tokens, @string, @start_pos, @length = tokens, string, start_pos, length
    end
    
    def inspect
      "#{tokens}, '#{string}', #{start_pos}, #{length}"
    end
  end
  
  class WhitespaceMatch
    attr_reader :string, :start_pos, :length
    
    def initialize(string, start_pos, length)
      @string, @start_pos, @length = string, start_pos, length
    end
    
    def inspect 
      "'#{string}', #{start_pos}, #{length}"
    end
  end

  class ParseException < Exception 
    attr_accessor :inputPos, :inputSymbol, :expected 
    def initialize(inputPos, inputSymbol, expected)
      @inputPos, @inputSymbol, @expected = inputPos, inputSymbol, expected
    end
  end
  
  class KanoccException < Exception
  end

  

end



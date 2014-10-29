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
# In Kanocc you could do it like this:
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
    attr_accessor :parser, :logger
    
    # Creates a new instance of Kannocc, with the given start symbol.
    # From the start_symbol, Kanocc will deduce the grammar and the 
    # grammarsymbols
    # 
    def initialize(start_symbol)
      @start_symbol = start_symbol
      @logger = Logger.new(STDOUT)
      @logger.datetime_format = "" 
      @logger.level = Logger::WARN
      @scanner = Scanner.new
      @scanner.set_recognized(*find_tokens(@start_symbol))
      @parser = EarleyParser.new(self, @logger)
    end
    
    def logger=(logger)
      @logger = logger || logger.new(STDOUT)
      @parser.logger = @logger if parser.respond_to?(:logger=)
    end
  
        
    # Consume input. Kanocc will parse input according to the rules given, and
    # - if parsing succeeds - return an instance of the grammars start symbol.
    # Input may be a String or an IO object.
    def parse(input)
      if input.is_a?(IO) 
        @input = input.readlines.join("")
      elsif input.is_a?(String) 
        @input = input
      else
        raise "Input must be a string or an IO object"
      end 
      raise "Start symbol not defined" unless @start_symbol
      @input = input
      @scanner.input = input
      @parser.start_symbol = @start_symbol 
      @stack = []
      @parser.parse(@scanner)
      @logger.info("Stack: " + @stack.inspect)
      @stack[0][0]
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
    def report_reduction(rule) 
      @logger.info "Reducing by " + rule.inspect
      raise "Fatal: stack too short!" if @stack.length < rule.rhs.length
      nonterminal = rule.lhs.new
      stack_part = @stack.slice!(-rule.rhs.length, rule.rhs.length)
      if rule.rhs.length > 0
        start_pos, end_pos = stack_part[0][1], stack_part[-1][2]
      elsif @stack.length > 0
        start_pos, end_pos =  @stack[-1][2], @stack[-1][2]
      else
        start_pos, end_pos = 0,0
      end 
      if rule.method
	rhs = Rhs.new(stack_part.map{|a| a[0]}, start_pos, end_pos, @input)
        old_rhs = nonterminal.instance_variable_get('@rhs')
        nonterminal.instance_variable_set('@rhs', rhs)
        nonterminal.send(rule.method)
        nonterminal.instance_variable_set('@rhs', old_rhs)
      end
      nonterminal_with_pos = [nonterminal.semantic_value, start_pos, end_pos]
      @stack.push(nonterminal_with_pos)
      show_stack
    end
    
    # The parser must call this method when it consumes a token
    # As argument it should give the LexicalMatch and the matched terminal.
    def report_token(lexical_match, terminal)
      start_pos = lexical_match.start_pos
      length = lexical_match.length
      stringpart = @input.slice(start_pos, length)
      if terminal.class == Class # It's a token
	instance = terminal.new
	regexp = lexical_match.regexp(terminal)
	instance.m = regexp.match(stringpart)
        if method = terminal.method(regexp)
	  instance.send(method)
	end
	instance = instance.semantic_value
      else # It's a string literal
	instance = terminal
      end

      @stack.push([instance, start_pos, start_pos + length])
      show_stack
    end
       
    def find_tokens(nonterminal)   
      collected_tokens = {}
      find_tokens_helper(nonterminal, collected_tokens)
      collected_tokens.keys
    end
    def find_tokens_helper(nonterminal, collected_tokens,  visited_nonterminals = {})
      unless visited_nonterminals[nonterminal]
        visited_nonterminals[nonterminal] = true
        nonterminal.rules.each do |r| 
          r.rhs.each do |gs|
            if gs.is_a?(Class) and gs.ancestors.member?(Nonterminal)
              find_tokens_helper(gs, collected_tokens, visited_nonterminals)
            else
              collected_tokens[gs] = true 
            end
          end
        end
      end
    end

    # For debugging
    def show_stack
      @logger.info("Stack: #{@stack.inspect}") if @logger
    end
    
    def show_grammar_symbols(tokens)
      "[" + tokens.map{|token| show_grammar_symbol(token)}.join(", ") + "]"
    end
    
    def show_grammar_symbol(gs) 
      if gs.is_a?(Token)
        "#{gs.class}(#{gs.m[0].inspect}, #{gs.start_pos}, #{gs.end_pos})" 
      elsif gs.is_a?(Nonterminal) 
        "#{gs.class}(#{gs.start_pos}, #{gs.end_pos})"
      else 
        gs.inspect
      end
    end

  end
    
  class Rhs < Array
    attr_reader :start_pos, :end_pos
    def initialize(arr, start_pos, end_pos, input)
      @start_pos, @end_pos, @input = start_pos, end_pos, input
      super(arr)
    end

    def text
      @input.slice(start_pos, end_pos - start_pos)
    end
    
    def inspect
      return "#{super.inspect}, #{start_pos.inspect}, #{end_pos.inspect}"
    end
  end
  
  class KanoccException < Exception
  end

  class ParseException < KanoccException
    attr_reader :expectedTerminals, :offendingInput, :pos
    def initialize(expected_terminals, offending_input, pos)
      @expected_terminals, @offending_input, @pos =
	expected_terminals, offending_input, pos
      error_msg = "\n  Could not consume input: #{offending_input} at #{pos}"
      if expected_terminals.size > 0
        error_msg += " - expected " +
                     "#{expected_terminals.map {|t| t.inspect}.join(" or ")}"
      else
        error_msg += " - no input could be consumed at this point."
      end
      super(error_msg)
    end
  end
end
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
#      setPattern(/\d+/) { @val = @m[0].to_i}
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
    # From the startsymbol, Kanocc will deduce the grammar and the 
    # grammarsymbols
    # 
    def initialize(startSymbol)
      @startSymbol = startSymbol 
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
      raise "Start symbol not defined" unless @startSymbol
      tellParserStartSymbol(@startSymbol) 
      @parser.prepare 
      @stack = []
      @inputPos = 0 
      @scanner.eachToken(input) do |tokens, startPos, endPos|
        @logger.info "got #{show(tokens)} from scanner at #{startPos}, #{endPos}"
        @logger.debug "Consume " + tokens.inspect if @logger
        @inputPos += 1
        @parser.consume(tokens, startPos, endPos)
      end
      @parser.eof
      @stack[0]
    end
   
    def parseFile(file)
      if file.is_a? String # Then we assume it's a path	
	file = File.open(File.expand_path(file))
	openedFile = true
      end
      input = file.read
      file.close if openedFile
      parse(input)
    end
    
    # Define whitespace. By default, Kanocc will recogninze anything that matches 
    # /\s/ as whitespace. 
    # whitespace takes a variable number of arguments, each of which must be a 
    # regular expression.
    def setWhitespace(*ws)
      @scanner.setWhitespace(*ws)
    end
    
    # Define which tokens Kanocc should recognize. If this method is not called
    # Kanocc will scan for those tokens that are mentioned in the grammar.
    # tokens= takes a variable number of arguments. Each argument must either be
    # a string or a class which is a subclass of Kanocc::Token
    def setTokens(*tokens)
      @scanner.setRecognized(*tokens)
    end
    
    # The parser must call this method when it have decided upon a reduction.
    # As arguments it should give the rule, by which to reduce. 
    def reportReduction(rule, startPos, endPos) 
      @logger.info "Reducing by " + rule.inspect
      nonterminal = rule.lhs.new      
      nonterminal.startPos = startPos
      nonterminal.endPos = endPos
      rightHandSide = @stack.slice!(-rule.rhs.length, rule.rhs.length)
      rightHandSide = rightHandSide.map {|e| e.is_a?(List) ? e.elements : e} unless nonterminal.is_a? List
      if rule.method
        oldRhs = nonterminal.instance_variable_get('@rhs')
        nonterminal.instance_variable_set('@rhs', rightHandSide)
        nonterminal.send(rule.method)
        nonterminal.instance_variable_set('@rhs', oldRhs)
      end
      @stack.push(nonterminal)
      showStack
    end
    
   
    # The parser must call this method when it consumes a token
    # As argument it should give the consumed token and the positions 
    # in the input string corresponding to the token. Positions should be given
    # as the position of the first character of the token and the position of the 
    # first character after the token.
    def reportToken(token)
      @logger.info("Pushing token: " + token.inspect)
      @stack.push(token)
      if token.respond_to?("__recognize__") 
        token.__recognize__ 
      end
      showStack 
    end
        
    
    def tellParserStartSymbol(startSymbol)
      @parser.startSymbol = startSymbol
      bagOfTerminals = {}
      findTokens(startSymbol, bagOfTerminals)
      @logger.debug "tokens = " + bagOfTerminals.keys.inspect 
      strings = bagOfTerminals.keys.find_all{|ter| ter.is_a? String} 
      @logger.info("Literals: " + strings.inspect)
      tokens = bagOfTerminals.keys.find_all{|ter| ter.is_a? Class and ter.ancestors.member?(Token)}
      @logger.info("Tokens: " + tokens.inspect)
      @scanner.setRecognized(*(strings + tokens))

      # Show rules
      @logger.info("Rules:")
      nonterminals = [startSymbol]
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
    
    def findTokens(nonterminal, collectedTokens,  visitedNonterminals = {})
      unless visitedNonterminals[nonterminal]
        visitedNonterminals[nonterminal] = true
        nonterminal.rules.each do |r| 
          r.rhs.each do |gs|
            if gs.is_a?(Class) and gs.ancestors.member?(Nonterminal)
              findTokens(gs, collectedTokens, visitedNonterminals)
            else
              collectedTokens[gs] = true 
            end
          end
        end
      end
    end
    
    def operatorPrecedence(rule)
      if operator = rule.operator
        rule.lhs.operatorPrecedence(operator) || 0
      else
        0
      end
    end
    
    # For debugging
    def showStack
      @logger.info("Stack: [" + @stack.map {|gs| show(gs)}.join(", ") + "]" ) if @logger
    end
    
    def show(gs)
      if gs.is_a?(Nonterminal) or gs.is_a?(Token)
        gs.class.to_s; 
      elsif gs.is_a?(String)
        gs.inspect; 
      end
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



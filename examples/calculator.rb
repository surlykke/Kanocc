#!/usr/bin/env ruby
#require "rubygems"
$:.unshift("lib")
require "kanocc.rb"
require "logger"
#require "breakpoint"

# Example use of Kanocc for a small calculator program.
# It implements the grammar:
#
# Program ::=
#           | Program Expr '\n'R
# Expr    ::= Expr '+' Expr 
#           | Expr '-' Expr 
#           | Expr '*' Expr 
#           | Expr '/' Expr 
#           | '(' Expr ')' 
#           | Number 
#
# With the lexical grammar:
#
# Number ::= \d+, '(', ')', '+', '-', '*', '/' '\n'


# ==========  Define a lexical grammar =============
class Number < Kanocc::Token
  attr_reader :val
  setPattern(/\d+/) {@val = eval @m[0]}
end

# ==========  Define a grammar =====================
class Expr < Kanocc::Nonterminal
  attr_reader :val
  
  rule(Expr, "+", Expr)  {@val = @rhs[0].val + @rhs[2].val}
  rule(Expr, "-", Expr)  {@val = @rhs[0].val - @rhs[2].val}
  rule(Expr, "*", Expr)  {@val = @rhs[0].val * @rhs[2].val}
  rule(Expr, "/", Expr)  {@val = @rhs[0].val / @rhs[2].val}
  rule("(", Expr, ")")   {@val = @rhs[1].val}
  rule(Number)           {@val = @rhs[0].val}
  
  setOperatorPrecedence ['*', '/'], 2
end

class Line < Kanocc::Nonterminal
  rule(Expr, "\n")   { p @rhs[0].val}
  rule(Kanocc::Error, "\n") do 
    puts "Sorry - didn't understand: #{$source[startPos, endPos-startPos].inspect}"
  end
end

class Program < Kanocc::Nonterminal
  rule(Program, Line)
  rule()
end

# Make a parser, give it 'Program' as the grammars startsymbol and run

parser = Kanocc::Kanocc.new(Program)
#parser.logger.level = Logger::DEBUG
$source = <<-EOF
  2 * 3
  3 - 3 +
  7 - 2 - 1
  3 * 2 + 4
  4 + 3 * 3
EOF

parser.parse($source)

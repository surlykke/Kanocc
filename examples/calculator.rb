#!/usr/bin/env ruby
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
libdir = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
#$:.unshift(libdir)
#require "kanocc.rb"
require 'rubygems'
require 'kanocc'
require "logger"
#require "breakpoint"

# Example use of Kanocc for a small calculator program.
# It implements the grammar:
#
# Program ::= Line+ 
# Line    ::= Expr "\n"
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
  set_pattern(/\d+/) {@val = eval @m[0]}
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
  
  set_operator_precedence ['*', '/'], 2
end

class Line < Kanocc::Nonterminal
  rule(Expr, "\n")   { p @rhs[0].val}
  rule(Kanocc::Error, "\n") do 
    puts "Sorry - didn't understand: #{$source[start_pos, end_pos-start_pos].inspect}"
  end
end

class Program < Kanocc::Nonterminal
  rule(zm(Line))
end

# Make a parser, give it 'Program' as the grammars startsymbol

parser = Kanocc::Kanocc.new(Program)

# Feed it some input
$source = <<-EOF
  2 * 3
  3 - 3 +
  7 - 2 - 1
  3 * 2 + 4
  4 + 3 * 3
EOF
puts "parsing: \n" + $source

# and go
parser.parse($source)

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
$:.unshift(libdir)
require "kanocc.rb"
require 'rubygems'
#require 'kanocc'
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
  pattern(/\d+/) {@sem_val = @m[0].to_i}
  pattern(/0x[0-9A-F]+/) {@sem_val = @m[0].hex}
end

# ==========  Define a grammar =====================
class Expr < Kanocc::Nonterminal
  rule(Expr, "+", Expr)  {@sem_val = @rhs[0] + @rhs[2]}
  rule(Expr, "-", Expr)  {@sem_val = @rhs[0] - @rhs[2]}
  rule(Expr, "*", Expr)  {@sem_val = @rhs[0] * @rhs[2]}; precedence -1
  rule(Expr, "/", Expr)  {@sem_val = @rhs[0] / @rhs[2]}; precedence -1
  rule("(", Expr, ")")   {@sem_val = @rhs[1]}
  rule(Number)           {@sem_val = @rhs[0]}
end

class Line < Kanocc::Nonterminal
  rule(Expr, "\n")   do
    str = $source[@rhs.start_pos..@rhs.end_pos - 2]
    puts str + " gives: " + @rhs[0].to_s
  end
end

class Program < Kanocc::Nonterminal
  rule(zm(Line))
end

# Make a parser, give it 'Program' as the grammars startsymbol

parser = Kanocc::Kanocc.new(Program)

#parser.logger.level = Logger::INFO

# Feed it some input

$source = <<-EOF
  2 + 3
  7 - 2 - 1
  3 * 2 + 4
  4 + 3 * 3
	8 - 3/2
EOF


puts "parsing: \n" + $source

# and go
parser.parse($source)



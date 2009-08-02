#!/usr/bin/env ruby
libdir = File.expand_path(File.join(File.dirname(__FILE__), "..", "lib"))
$:.unshift(libdir)
require "kanocc.rb"
require "logger"

class Number < Kanocc::Token
  attr_reader :val
  pattern(/\d+/) {@val = @m[0].to_i}
end

class Expr < Kanocc::Nonterminal
  attr_reader :val
  rule(Expr, "-", Expr) {@val = @rhs[0].val - @rhs[2].val}; 
  rule(Expr, "+", Expr) {@val = @rhs[0].val + @rhs[2].val}; 
  rule(Number) {@val = @rhs[0].val}
end

# Make a parser, give it 'Program' as the grammars startsymbol

parser = Kanocc::Kanocc.new(Expr)
#parser.logger.level = Logger::INFO

puts parser.parse("7 - 5 + 3").val
puts parser.parse("7 - 3 - 2").val


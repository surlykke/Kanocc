#!/usr/bin/env ruby
require "kanocc"
require 'logger'

class Number < Kanocc::Token 
  attr_reader :val 
  pattern(/\d+/) { @val = @m[0].to_i} 
end

class Expr < Kanocc::Nonterminal 
  attr_reader :val

  rule(Expr, "+", Expr) { @val = @rhs[0].val + @rhs[2].val}
  rule(Expr, "-", Expr) { @val = @rhs[0].val - @rhs[2].val}
  rule(Expr, "*", Expr) { @val = @rhs[0].val * @rhs[2].val}; precedence(-1);
  rule(Expr, "/", Expr) { @val = @rhs[0].val / @rhs[2].val}; precedence(-1); 
  rule("(", Expr, ")") { @val = @rhs[1].val}
  rule(Number) {@val = @rhs[0].val}

  bind_right('-')  
end

#class Line < Kanocc::Nonterminal
#  rule(Expr, "\n") {puts @rhs[0].val}
#  rule(Kanocc::Error, "\n") {puts "Sorry - didn't understand: " + @rhs[0].str.inspect}
#end
#
#class Program < Kanocc::Nonterminal
#  rule(zm(Line)) 
#end
#
parser = Kanocc::Kanocc.new(Expr)
parser.logger.level = Logger::INFO

prog = <<-EOI
  8 - 4 + 2 
EOI

puts prog.inspect
Expr.show_all_rules

puts parser.parse(prog).val

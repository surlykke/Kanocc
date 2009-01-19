#!/usr/bin/env ruby
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))

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
  rule(Expr, "*", Expr) { @val = @rhs[0].val * @rhs[2].val}
  rule(Expr, "/", Expr) { @val = @rhs[0].val / @rhs[2].val} 
  rule("(", Expr, ")") { @val = @rhs[1].val}
  rule(Number) {@val = @rhs[0].val}

  set_operator_precedence(['*', '/'], -1)
end

class Line < Kanocc::Nonterminal
  rule(Expr, "\n") {puts @rhs[0].val}
  rule(Kanocc::Error, "\n") {puts "Sorry - didn't understand: " + @rhs[0].str.inspect}
end

class Program < Kanocc::Nonterminal
  rule(zm(Line)) 
end

parser = Kanocc::Kanocc.new(Program)
#parser.logger.level = Logger::DEBUG

prog = <<-EOI
  8 - 3 * *
EOI

puts prog.inspect
Program.show_all_rules
parser.parse(prog)
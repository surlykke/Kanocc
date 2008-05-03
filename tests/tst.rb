#!/usr/bin/ruby
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require "kanocc"

class Expr < Kanocc::Nonterminal
  attr_reader :val
  rule({Expr=>:e1}, "+", {Expr=>:e2}) {@val = e1.val + e2.val}
end

puts Expr.new.methods.sort.inspect

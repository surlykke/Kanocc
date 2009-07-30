#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'kanocc'
require 'kanocc/earley'

module Kanocc
  class TestEarley < Test::Unit::TestCase
    def setup

    end

    def test_operator_precedence
      num = Class.new(Token)
      eval('::Num = num')
      num.send(:attr_accessor, :val)
      num.pattern(/\d+/) {@val = @m[0].to_i}
      num.method(:inspect) {"Num"}

      expr = Class.new(Nonterminal)
      eval('::Expr = expr')
      expr.send(:attr_accessor, :val)
      expr.rule(num) {@val = @rhs[0].val}
      expr.rule(expr, '+', expr) {@val = @rhs[0].val + @rhs[2].val}
      expr.rule(expr, '*', expr) {@val = @rhs[0].val * @rhs[2].val}

      expr.precedence('*', -2)
      parser = Kanocc.new(expr)

      assert_equal(10, parser.parse("2 * 3 + 4").val)
      assert_equal(14, parser.parse("2 + 3 * 4").val)
    end

  end


end

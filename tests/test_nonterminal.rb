#!/usr/bin/env ruby
$:.unshift File.join(File.dirname(__FILE__),'..','lib')

require 'test/unit'
require 'kanocc'
require 'kanocc/earley'

module Kanocc
  class TestNonterminal < Test::Unit::TestCase

    def test_operator_precedence
       n = Class.new(Nonterminal)
       n.precedence('*', '/', -2)
       assert_equal(0, n.operator_precedence('+'))
       assert_equal(-2, n.operator_precedence('*'))
       assert_equal(-2, n.operator_precedence('/'))
    end

  end


end

#!/usr/bin/env ruby
require 'test/unit'
require 'logger'
lib = File.expand_path((File.join(File.dirname(__FILE__), '..', 'lib')))
$:.unshift(lib)
p $:
require 'kanocc'

module Kanocc
  class TestKanocc < Test::Unit::TestCase

    def test_initialize
      dummy = Class.new(Nonterminal)
      kanocc = Kanocc.new(dummy)
      assert_equal(kanocc.logger.level, Logger::WARN)
      assert(kanocc.scanner.is_a?(Scanner))
      assert(kanocc.parser.is_a?(EarleyParser))

      myScanner = Object.new
      myParser = Object.new
      myLogger = Logger.new(STDOUT)
      myLogger.level = Logger::INFO
      kanocc = Kanocc.new(:scanner=>myScanner, :parser=>myParser, :logger=>myLogger)
      assert_equal(myLogger, kanocc.logger)
      assert_equal(myScanner, kanocc.scanner)
      assert_equal(myParser, kanocc.parser)
    end

    def test_assign_logger
      dummy = Class.new(Nonterminal)
      kanocc = Kanocc.new(dummy)
      myLogger = Object.new
      class << myLogger
	attr_accessor :logger
      end
      kanocc.logger = myLogger
      assert_equal(kanocc.logger, myLogger)
      assert_equal(kanocc.parser.logger, myLogger)
      assert_equal(kanocc.scanner.logger, myLogger)

    end

    def test_report_reduction
      # Test Stack is stripped correctly
      # New instance correctly pushed
      # Right instances pushed into rule method

      myRule = GrammarRule.new(A, [B, T, C], :method)
      ruleB = GrammarRule.new(B, [], nil)
      ruleC = GrammarRule.new(C, [], nil)
      kanocc = Kanocc.new
      kanocc.rapportReduction(ruleB)
      kanocc.rapportToken(T.new)
      kanocc.rapportRule(ruleC)


    end
  end

  class A < Nonterminal
    def method
      @rhs # We return what kanocc injects as rhs, so that the test can inspect it.
    end
  end

  class B < Nonterminal
  end

  class T < Token
  end

  class C < Nonterminal
  end
end
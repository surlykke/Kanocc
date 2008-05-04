#!/usr/bin/ruby
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
require 'logger'
$:.unshift(File.expand_path(File.join(File.dirname(__FILE__), '..', 'lib')))
require "kanocc"

# ======== Bracket Packing Grammar ========
# Package     ::=  '(' 'B' ')'
#               |  '{' 'B' '}'
#               |  '[' 'B' ']'
#               |  '(' PackageList ')'
#               |  '{' PackageList '}'
#               |  '[' PackageList ']'
#
# PackageList ::= Package
#               | PackageList Package

class PackageList < Kanocc::Nonterminal
end

class Package < Kanocc::Nonterminal
  attr_reader :val
  rule('(', 'B', ')') { @val = '(B)' } 
  rule('{', 'B', '}') { @val = '{B}' } 
  rule('[', 'B', ']') { @val = '[B]' }
  rule('(', PackageList , ')') { @val = '(' + @rhs[1].val + ')'} 
  rule('{', PackageList , '}') { @val = '{' + @rhs[1].val + '}'} 
  rule('[', PackageList , ']') { @val = '[' + @rhs[1].val + ']'} 
  # Some error-correcting rules 
  rule(PackageList, ')') {@val = '(' + @rhs[0].val + ')'}; prec -2
  rule('(', PackageList) {@val = '(' + @rhs[1].val + ')'}; prec -2
  rule(PackageList, '}') {@val = '{' + @rhs[0].val + '}'}; prec -2
  rule('{', PackageList) {@val = '{' + @rhs[1].val + '}'}; prec -2
  rule(PackageList, ']') {@val = '[' + @rhs[0].val + ']'}; prec -2
  rule('[', PackageList) {@val = '[' + @rhs[1].val + ']'}; prec -2
end

class PackageList 
  attr_reader :val
  rule(Package){ @val = @rhs[0].val }
  rule(PackageList, Package){@val = @rhs[0].val + @rhs[1].val}
end

# Set up a parser 
packageChecker = Kanocc::Kanocc.new(Package)
#packageChecker.logger.level = Logger::DEBUG 
# And go
puts "[(B)] becomes " + packageChecker.parse('[(B)]').val
puts "[[B] becomes " + packageChecker.parse('[[B]').val

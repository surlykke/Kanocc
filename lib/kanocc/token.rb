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
module Kanocc
  class Token < Regexp
    attr_reader :str
    attr_accessor :m
    
    @@patterns = Hash.new
  
    def initialize(str)
      @str = str
      super(@@patterns[self.class])
    end
      
    def ===(klass)
      self.class == klass
    end
    
    def Token.setPattern(reg, &block)
      @@patterns[self] = reg
      if block_given?
        define_method(:__recognize__, &block)
      end
    end
  
    def Token.pattern
      return @@patterns[self]
    end

    def is_a_kanocc_token?
      return true
    end

    def Token.is_a_kanocc_grammarsymbol?
      return true
    end

    def inspect
      self.class.name + "[" + @str + "]" 
    end
  end
end

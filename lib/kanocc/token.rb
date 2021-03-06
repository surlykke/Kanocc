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
  class Token
    attr_accessor :m
    
    @@patterns = Hash.new
  
    def ===(klass)
      self.class == klass
    end
    
    def Token.pattern(reg, &block)
      raise "pattern must be given a Regexp as it's first argument" unless reg.is_a?(Regexp)
      @@patterns[self] = [] unless @@patterns[self]
      if block_given?
        method_name = ("pattern " + reg.inspect).to_sym
        define_method(method_name, &block)
      else
	method_name = nil
      end
      @@patterns[self] << {:token => self, 
	                   :regexp => reg, 
			   :method_name=>method_name}
    end
  
    def Token.patterns
      return @@patterns[self] || []
    end

    def Token.regexps
      return (@@patterns[self] || []).map {|pattern| pattern[:regexp]}
    end

    def Token.method(regexp)
      patterns.find {|pattern| pattern[:regexp] == regexp}[:method_name]
    end

    def is_a_kanocc_token?
      return true
    end

    def Token.is_a_kanocc_grammarsymbol?
      return true
    end

    def Token.match(string_scanner)
      max_match_len = 0
      matching_regexp = nil
      regexps.each do |regexp|
	if (len = string_scanner.match?(regexp)) and len > max_match_len
	  max_match_len = len
	  matching_regexp = regexp
	end
      end
      if matching_regexp
        return max_match_len, matching_regexp
      else
	return 0, nil
      end
    end

    def inspect
      self.class.name 
    end

    def semantic_value
      return @sem_val || self
    end
  end
end

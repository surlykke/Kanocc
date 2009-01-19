#!/usr/bin/env ruby
puts "Goto: " + File.dirname(__FILE__) + "/../docs" 
Dir.chdir( File.dirname(__FILE__) + "/../docs")
puts Dir.getwd
`linuxdoc -B html Kanocc.sgml --split=0` 
`mv Kanocc.html ../www` 

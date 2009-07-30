#!/usr/bin/ruby -w
require 'xml/libxslt'
this_dir = File.dirname(__FILE__)
xslt = XML::XSLT.new()
path_to_docbook_stylesheets = 
xslt.xml = this_dir + "/../docs/Kanocc.xml" 
xslt.xsl = "/usr/share/xml/docbook/stylesheet/nwalsh/html/docbook.xsl"
path_to_output = this_dir + "/../www/Kanocc.html" 
File.open(path_to_output, "w") do |f|
	f.print(xslt.serve())
end

#!/usr/bin/env ruby 
# You must have the tool docbook2html in path before you execute this script.
# I don't know if it will work on windows.
#
# TODO: Build rdoc stuff
#
rootdir = File.expand_path(File.join(File.dirname(__FILE__), ".."))
source = File.join(rootdir, "docs", "Kanocc.xml")
destdir = File.join(rootdir, "www")
system("docbook2html -u -o #{destdir}  #{source}")

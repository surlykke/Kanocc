#!/usr/bin/env ruby
require 'rubygems'
spec = Gem::Specification.new do |s|
  s.name      = "kanocc"
  s.version = "0.1.0"
  s.author    = "Christian Surlykke"
  s.email     = ""
  s.homepage = ""
  s.platform = Gem::Platform::RUBY
  s.summary = "Kanocc - Kanocc ain't no compiler-compiler. A framework for syntax directed translation"
  candidates = Dir.glob("{doc,lib,test,examples}/**/*")
  s.files     = candidates.delete_if do |item|
                  item.include?("rdoc")
                end
  s.require_path = "lib"
  s.autorequire = "kanocc"
end

if $0 == __FILE__
  Gem::manage_gems
  Gem::Builder.new(spec).build
end


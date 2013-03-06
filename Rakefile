# encoding: utf-8

require 'rubygems'
require 'bundler'
begin
  Bundler.setup(:default, :development)
rescue Bundler::BundlerError => e
  $stderr.puts e.message
  $stderr.puts "Run `bundle install` to install missing gems"
  exit e.status_code
end
require 'rake'

require 'jeweler'
Jeweler::Tasks.new do |gem|
  # gem is a Gem::Specification... see http://docs.rubygems.org/read/chapter/20 for more options
  gem.name = "timeout-interrupt"
  gem.homepage = "http://github.com/DenisKnauf/ruby-timeout-interrupt"
  gem.license = "AGPLv3"
  gem.summary = %Q{"Interrupts systemcalls too."}
  gem.description = %Q{Timeout-lib, which interrupts everything, also systemcalls. It uses libc-alarm.}
  gem.email = "Denis.Knauf@gmail.com"
  gem.authors = ["Denis Knauf"]
  # dependencies defined in Gemfile
end
Jeweler::RubygemsDotOrgTasks.new

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

#require 'simplecov'
#Rcov::RcovTask.new do |test|
  #test.libs << 'test'
  #test.pattern = 'test/**/test_*.rb'
  #test.verbose = true
  #test.rcov_opts << '--exclude "gems/*"'
#end

task :default => :test

require 'yard'
YARD::Rake::YardocTask.new

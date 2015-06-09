# Gemfile

require "rubygems"
require "bundler/setup"
require "sinatra"
require "mongoid"
require "SecureRandom"
require "digest"
require "digest/bubblebabble"
require File.dirname(__FILE__) + '/app.rb'

set :run, false
set :raise_errors, true

run Sinatra::Application
# Gemfile

require "rubygems"
require "bundler/setup"
require "sinatra"
require "mongoid"
require "securerandom"
require "digest"
require "digest/bubblebabble"
require "dragonfly"
require "dragonfly/s3_data_store"
require "aws-sdk"

require File.dirname(__FILE__) + '/app.rb'

set :run, false
set :raise_errors, true

run Sinatra::Application

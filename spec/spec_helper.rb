# Load the main file
require_relative '../module/postoffice'

# Dependencies
require 'minitest/autorun'
require 'minitest/reporters'
require 'webmock/minitest'
require 'rack/test'
require 'bundler/setup'
require 'rubygems'
require 'mongoid'

Bundler.require(:default)

Mongoid.load!('config/mongoid.yml')

#Minitest reporter
reporter_options = { color: true}
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]
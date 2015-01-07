# Load the main file
require_relative '../module/postoffice'
require_relative '../app'

# Dependencies
require 'minitest/autorun'
require 'minitest/reporters'
require 'webmock/minitest'
require 'rack/test'
require 'bundler/setup'
require 'rubygems'
require 'mongoid'
require 'mocha/setup'

Bundler.require(:default)

#Minitest reporter
reporter_options = { color: true}
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]
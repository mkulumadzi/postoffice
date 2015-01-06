# Load the main file
require_relative '../module/posnail-office'

# Dependencies
require 'minitest/autorun'
require 'pry'
require 'minitest/reporters'
require 'webmock/minitest'

#Minitest reporter
reporter_options = { color: true}
Minitest::Reporters.use! [Minitest::Reporters::DefaultReporter.new(reporter_options)]
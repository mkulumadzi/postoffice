# Load the main file
require_relative '../module/postoffice'
require_relative '../app'

# Load Factories (these weren't loading by default)
require_relative './factories.rb'

# Load convenience methods for testing
require_relative './convenience_methods.rb'

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

# Include Factory Girl in MiniTest
class MiniTest::Unit::TestCase
  include FactoryGirl::Syntax::Methods
end

class MiniTest::Spec
  include FactoryGirl::Syntax::Methods
end
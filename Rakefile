ENV['RACK_ENV'] = 'development'

require 'rake/testtask'
require 'bundler/setup'
require 'mongoid'

Rake::TestTask.new do |t|
	t.test_files = FileList['spec/lib/postoffice/*_spec.rb']
	t.verbose = true
end

Mongoid.load!("config/mongoid.yml")

task :default => :test
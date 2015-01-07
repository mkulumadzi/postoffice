require 'rake/testtask'
require 'bundler/setup'

Rake::TestTask.new do |t|
	t.test_files = FileList['spec/lib/postoffice/*_spec.rb']
	t.verbose = true
end

task :default => :test
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

namespace :db do
    task :create_indexes, :environment do |t, args|
        unless args[:environment]
            puts "Must provide an environment"
            exit
        end

        yaml = YAML.load_file("mongoid.yml")

        env_info = yaml[args[:environment]]
        unless env_info
            puts "Unknown environment"
            exit
        end

        Mongoid.configure do |config|
            config.from_hash(env_info)
        end

        SnailMail::Person.create_indexes
    end
end
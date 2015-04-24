ENV['RACK_ENV'] = 'development'

require 'rake/testtask'
require 'bundler/setup'
require 'mongoid'
require_relative 'module/postoffice.rb'

Rake::TestTask.new do |t|
	t.test_files = FileList['spec/lib/postoffice/*_spec.rb']
	t.verbose = true
end

Mongoid.load!("config/mongoid.yml")

task :default => :test

task :create_indexes do

	Mongoid.load!("config/mongoid.yml")
	SnailMail::Person.create_indexes

end

task :setup_demo_data do

	Mongoid.load!("config/mongoid.yml")

	SnailMail::Mail.delete_all
	SnailMail::Person.delete_all

	SnailMail::Person.create!({
      username: "bigedubs",
      name: "Evan Waters",
      address1: "121 W 3rd St",
      city: "New York",
      state: "NY",
      zip: "10012"
    })

	SnailMail::Person.create!({
      username: "nwaters",
      name: "Neal Waters",
      address1: "44 Prichard St",
      city: "Somerville",
      state: "MA",
      zip: "02132"
    })

	SnailMail::Person.create!({
      username: "kulwelling",
      name: "Kristen Ulwelling",
      address1: "121 W 3rd St",
      city: "New York",
      state: "NY",
      zip: "10012"
    })

    mail1 = SnailMail::Mail.create!({
    	from: "nwaters",
    	to: "bigedubs",
    	content: "Hey bro, how's it going? Would you like to watch the game?"
    })

    mail1.mail_it
    mail1.deliver_now

    mail2 = SnailMail::Mail.create!({
    	from: "kulwelling",
    	to: "bigedubs",
    	content: "Greetings from NOLA!"
    })

    mail2.mail_it
    mail2.deliver_now

    mail3 = SnailMail::Mail.create!({
    	from: "nwaters",
    	to: "bigedubs",
    	content: "Go U of A!"
    })

    mail3.mail_it

end
# ENV['RACK_ENV'] = 'development'

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

  data = "{'username': 'evan.waters@gmail.com', 'password': 'password', 'name': 'Evan Waters'"
  SnailMail::PersonService.create_person data


	SnailMail::Person.create!({
      username: "nwaters4@gmail.com",
      name: "Neal Waters",
      address1: "44 Prichard St",
      city: "Somerville",
      state: "MA",
      zip: "02132"
    })

	SnailMail::Person.create!({
      username: "kulwelling@gmail.com",
      name: "Kristen Ulwelling",
      address1: "121 W 3rd St",
      city: "New York",
      state: "NY",
      zip: "10012"
    })

    mail1 = SnailMail::Mail.create!({
    	from: "nwaters4@gmail.com",
    	to: "evan.waters@gmail.com",
    	content: "Hey bro, how's it going? Would you like to watch the game?"
    })

    mail1.mail_it
    mail1.deliver_now
    mail1.update_delivery_status
    mail1.read

    mail2 = SnailMail::Mail.create!({
    	from: "kulwelling@gmail.com",
    	to: "evan.waters@gmail.com",
    	content: "Greetings from NOLA!",
      image: "Fireworks.jpg"
    })

    mail2.mail_it
    mail2.deliver_now
    mail1.update_delivery_status

    mail3 = SnailMail::Mail.create!({
    	from: "nwaters4@gmail.com",
    	to: "evan.waters@gmail.com",
    	content: "Go U of A!",
      image: "Dhow.jpg"
    })

    mail3.mail_it

end

task :notify_recipients do
  SnailMail::MailService.deliver_mail_and_notify_recipients
end
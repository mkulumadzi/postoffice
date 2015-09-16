# ENV['RACK_ENV'] = 'development'

require 'rake/testtask'
require 'bundler/setup'
require 'mongoid'

require_relative 'module/postoffice.rb'

Rake::TestTask.new do |t|
	t.test_files = FileList['spec/lib/postoffice/*_spec.rb']
	t.verbose = true
end

Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])

task :default => :test

task :create_indexes do

	Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])
	Postoffice::Person.create_indexes
	Postoffice::Token.create_indexes
	Postoffice::Contact.create_indexes
	Postoffice::Conversation.create_indexes

end

task :remove_indexes do

  Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])
  Postoffice::Person.remove_indexes
	Postoffice::Token.remove_indexes
	Postoffice::Contact.remove_indexes
	Postoffice::Conversation.remove_indexes
end

task :setup_demo_data do

	if ENV["RACK_ENV"] == "production"
		puts "Cannot setup demo data on production environment"
		return nil
	end

	Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])
	Mongoid.logger.level = Logger::INFO
	Mongo::Logger.logger.level = Logger::INFO

	Postoffice::Mail.delete_all
	Postoffice::Person.delete_all
	Postoffice::Token.delete_all
	Postoffice::Contact.delete_all
	Postoffice::Conversation.delete_all

	Postoffice::Person.create!({
			username: "postman",
			email: "postman@slowpost.me",
			name: "Slowpost Postman",
			phone: "5554441234",
			address1: nil,
			city: nil,
			state: nil,
			zip: nil
		})

  data =  JSON.parse '{"name": "Evan Waters", "username": "evan.waters", "email": "evan.waters@gmail.com", "phone": "(555) 444-1324", "address1": "121 W 3rd St", "city": "New York", "state": "NY", "zip": "10012", "password": "password"}'
  person = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message person

	data =  JSON.parse '{"name": "Neal Waters", "username": "nwaters4", "email": "nwaters4@gmail.com", "phone": "(555) 444-1234", "address1": "44 Prichard St", "city": "Somerville", "state": "MA", "zip": "02132", "password": "password"}'
	person1 = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message person1

	data =  JSON.parse '{"name": "Kristen Ulwelling", "username": "kulwelling", "email": "kulwelling@gmail.com", "phone": "(555) 444-4321", "address1": "121 W 3rd St", "city": "New York", "state": "NY", "zip": "10012", "password": "password"}'
	person2 = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message person2

	data =  JSON.parse '{"name": "Demo User", "username": "demo", "email": "demo@test.com", "phone": "(555) 444-4555", "password": "password"}'
	demo = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message demo

		# image1 = File.open('spec/resources/image1.jpg')
		# uid1 = Dragonfly.app.store(image1.read, 'name' => 'image1.jpg')
		# image1.close
		#
		# image2 = File.open('spec/resources/image2.jpg')
		# uid2 = Dragonfly.app.store(image2.read, 'name' => 'image2.jpg')
		# image2.close


		f1 = Postoffice::FromPerson.new(person_id: person1.id)
		t1 = Postoffice::ToPerson.new(person_id: person.id)
    mail1 = Postoffice::Mail.create!({
    	content: "Hey bro, how's it going? Would you like to watch the game?",
			correspondents: [f1, t1]
    })

    mail1.mail_it
    mail1.deliver

		f2 = Postoffice::FromPerson.new(person_id: person2.id)
		t2 = Postoffice::ToPerson.new(person_id: person.id)
		t2b = Postoffice::ToPerson.new(person_id: person1.id)
    mail2 = Postoffice::Mail.create!({
    	content: "Greetings from NOLA!",
			correspondents: [f2, t2, t2b]
    })

    mail2.mail_it
    mail2.deliver

		f3 = Postoffice::FromPerson.new(person_id: person1.id)
		t3 = Postoffice::ToPerson.new(person_id: person.id)
    mail3 = Postoffice::Mail.create!({
    	content: "Go U of A!",
			correspondents: [f3, t3]
    })

		mail3.mail_it

		f4 = Postoffice::FromPerson.new(person_id: person.id)
		t4 = Postoffice::ToPerson.new(person_id: demo.id)
		mail4 = Postoffice::Mail.create!({
			content: "Thanks for checking out the app! Looking forward to getting your feedback.",
			correspondents: [f4, t4]
		})

		mail4.mail_it
		mail4.deliver

		f5 = Postoffice::FromPerson.new(person_id: demo.id)
		t5 = Postoffice::ToPerson.new(person_id: person.id)
		mail5 = Postoffice::Mail.create!({
			content: "Can't wait to receive a few more Slowposts!",
			correspondents: [f5, t5]
		})

		mail5.mail_it

end

task :notify_recipients do
  puts "Notifying recipients for #{ENV['RACK_ENV']} environment"
  Postoffice::MailService.deliver_mail_and_notify_recipients ENV["POSTMARK_API_KEY"]
end

task :test_notification do
  puts "Sending test notification for #{ENV['RACK_ENV']} environment"
  people = Postoffice::Person.where(:device_token.exists => true, :device_token.ne => "abc123")
  notifications = Postoffice::NotificationService.create_notification_for_people people, "Test notification", "Test"
  puts "Sending notifications: #{notifications}"
  APNS.send_notifications(notifications)
end

task :migrate_data do
  require_relative 'db/migrate.rb'
end

task :give_me_binding do
	binding.pry
end

task :export_analytics do
	filepath = "/Users/bigedubs/Desktop"
	Postoffice::AnalyticsService.export_stats filepath
end

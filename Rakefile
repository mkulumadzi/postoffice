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
	Postoffice::Person.create_indexes

end

task :remove_indexes do

  Mongoid.load!("config/mongoid.yml")
  Postoffice::Person.remove_indexes

end

task :setup_demo_data do

	Mongoid.load!("config/mongoid.yml")

	Postoffice::Mail.delete_all
	Postoffice::Person.delete_all

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

		image1 = File.open('spec/resources/image1.jpg')
		uid1 = Dragonfly.app.store(image1.read, 'name' => 'image1.jpg')
		image1.close

		image2 = File.open('spec/resources/image2.jpg')
		uid2 = Dragonfly.app.store(image2.read, 'name' => 'image2.jpg')
		image2.close

    mail1 = Postoffice::Mail.create!({
    	from: "nwaters4",
    	to: "evan.waters",
    	content: "Hey bro, how's it going? Would you like to watch the game?"
    })

    mail1.mail_it
    mail1.deliver_now
    mail1.update_delivery_status
    mail1.read

    mail2 = Postoffice::Mail.create!({
    	from: "kulwelling",
    	to: "evan.waters",
    	content: "Greetings from NOLA!",
      image_uid: uid1
    })

    mail2.mail_it
    mail2.deliver_now
    mail1.update_delivery_status

    mail3 = Postoffice::Mail.create!({
    	from: "nwaters4",
    	to: "evan.waters",
    	content: "Go U of A!",
      image_uid: uid2
    })

		mail3.mail_it

		mail4 = Postoffice::Mail.create!({
			from: "evan.waters",
			to: "demo",
			content: "Thanks for checking out the app! Looking forward to getting your feedback.",
			image_uid: uid1
		})

		mail4.mail_it
		mail4.deliver_now
		mail4.update_delivery_status

		mail5 = Postoffice::Mail.create!({
			from: "demo",
			to: "evan.waters",
			content: "Can't wait to receive a few more Slowposts!",
			image_uid: uid2
		})

		mail5.mail_it

end

task :notify_recipients do
  puts "Notifying recipients for #{ENV['RACK_ENV']} environment"
  Postoffice::MailService.deliver_mail_and_notify_recipients
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

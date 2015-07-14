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

  data =  JSON.parse '{"name": "Evan", "username": "evan.waters", "email": "evan.waters@gmail.com", "phone": "(555) 444-1324", "address1": "121 W 3rd St", "city": "New York", "state": "NY", "zip": "10012", "password": "password"}'
  
  person = SnailMail::PersonService.create_person data

	SnailMail::Person.create!({
      username: "nwaters4",
      name: "Neal Waters",
      email: "nwaters4@gmail.com",
      phone: "5554441234",
      address1: "44 Prichard St",
      city: "Somerville",
      state: "MA",
      zip: "02132"
    })

  SnailMail::MailService.generate_welcome_message person

  SnailMail::Person.create!({
      username: "snailmail.kuyenda",
      email: "snailmail.kuyenda@gmail.com",
      name: "Snailtale Postman",
      address1: nil,
      city: nil,
      state: nil,
      zip: nil
    })


	SnailMail::Person.create!({
      username: "kulwelling",
      name: "Kristen Ulwelling",
      email: "kulwelling@gmail.com",
      address1: "121 W 3rd St",
      city: "New York",
      state: "NY",
      zip: "10012"
    })

    mail1 = SnailMail::Mail.create!({
    	from: "nwaters4",
    	to: "evan.waters",
    	content: "Hey bro, how's it going? Would you like to watch the game?"
    })

    mail1.mail_it
    mail1.deliver_now
    mail1.update_delivery_status
    mail1.read

    mail2 = SnailMail::Mail.create!({
    	from: "kulwelling",
    	to: "evan.waters",
    	content: "Greetings from NOLA!",
      image: "Fireworks.jpg"
    })

    mail2.mail_it
    mail2.deliver_now
    mail1.update_delivery_status

    mail3 = SnailMail::Mail.create!({
    	from: "nwaters4",
    	to: "evan.waters",
    	content: "Go U of A!",
      image: "Dhow.jpg"
    })

end

task :notify_recipients do
  puts "Notifying recipients for #{ENV['RACK_ENV']} environment"
  SnailMail::MailService.deliver_mail_and_notify_recipients
end

task :test_notification do
  puts "Sending test notification for #{ENV['RACK_ENV']} environment"
  people = SnailMail::Person.where(:device_token.exists => true, :device_token.ne => "abc123")
  notifications = SnailMail::NotificationService.create_notification_for_people people, "Test notification", "Test"
  puts "Sending notifications: #{notifications}"
  APNS.send_notifications(notifications)
end

task :migrate_data do
  require_relative 'db/migrate.rb'
end
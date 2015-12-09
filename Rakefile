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
	Postoffice::Conversation.create_indexes
	Postoffice::QueueItem.create_indexes

end

task :remove_indexes do

  Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])
  Postoffice::Person.remove_indexes
	Postoffice::Token.remove_indexes
	Postoffice::Conversation.remove_indexes
	Postoffice::QueueItem.remove_indexes

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
	Postoffice::Conversation.delete_all
	Postoffice::QueueItem.delete_all

	Postoffice::Person.create!({
			username: "postman",
			email: "postman@slowpost.me",
			given_name: "Slowpost",
			family_name: "Postman",
			phone: "5554441234",
			address1: nil,
			city: nil,
			state: nil,
			zip: nil
		})

  data =  JSON.parse '{"given_name": "Evan", "family_name": "Waters", "username": "evan.waters", "email": "evan.waters@gmail.com", "phone": "(555) 444-1324", "address1": "121 W 3rd St", "city": "New York", "state": "NY", "zip": "10012", "password": "password"}'
  evan = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message evan

	data =  JSON.parse '{"given_name": "George", "family_name": "Byron", "username": "gbyron", "email": "gbyron@thebyrons.com", "phone": "(555) 444-1234", "address1": "1 White Hard Lane", "city": "London", "state": "UK", "zip": "NA", "password": "password"}'
	byron = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message byron

	data =  JSON.parse '{"given_name": "Ada", "family_name": "Lovelace", "username": "alovelace", "email": "ada@thelovelaces.com", "phone": "(555) 444-4321", "password": "password"}'
	ada = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message ada

	data =  JSON.parse '{"given_name": "William", "family_name": "Lovelace", "username": "wlovelace", "email": "wlovelace@thelovelaces.com", "password": "password"}'
	william = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message william

	data =  JSON.parse '{"given_name": "Annie", "family_name": "Haro", "username": "aharo", "email": "anna-haro@mac.com", "phone": "555-444-5431", "password": "password"}'
	annie = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message annie

	data =  JSON.parse '{"given_name": "Demo", "family_name": "User", "username": "demo", "email": "demo@test.com", "phone": "(555) 444-4555", "password": "password"}'
	demo = Postoffice::PersonService.create_person data
	Postoffice::MailService.generate_welcome_message demo

	image1 = File.open('spec/resources/image1.jpg')
	uid1 = Dragonfly.app.store(image1.read, 'name' => 'image1.jpg')
	image1.close

	image2 = File.open('spec/resources/image2.jpg')
	uid2 = Dragonfly.app.store(image2.read, 'name' => 'image2.jpg')
	image2.close


	f1 = Postoffice::FromPerson.new(person_id: byron.id)
	t1 = Postoffice::ToPerson.new(person_id: ada.id)
	n1 = Postoffice::Note.new(content: "Dearest Ada, it was so lovely to see you and William on your recent visit. I reall do think your counting machine is going to be something special. Do write as soon as you are home! Yours, Lord Byron")
	i1 = Postoffice::ImageAttachment.new(image_uid: uid1)
  mail1 = Postoffice::Mail.create!({
		correspondents: [f1, t1],
		attachments: [n1, i1]
  })

  mail1.mail_it
  mail1.deliver
	mail1.read_by ada

	f2 = Postoffice::FromPerson.new(person_id: byron.id)
	t2 = Postoffice::ToPerson.new(person_id: william.id)
	t2b = Postoffice::ToPerson.new(person_id: ada.id)
	t2c = Postoffice::Email.new(email: "thepress@thepress.com")
	n2 = Postoffice::Note.new(content: "Greetings from NOLA!")
	i2 = Postoffice::ImageAttachment.new(image_uid: uid2)
  mail2 = Postoffice::Mail.create!({
		correspondents: [f2, t2, t2b, t2c],
		attachments: [n2, i2]
  })

  mail2.mail_it
  mail2.deliver

	f3 = Postoffice::FromPerson.new(person_id: ada.id)
	t3 = Postoffice::ToPerson.new(person_id: byron.id)
	n3 = Postoffice::Note.new(content: "What a lovely view.")
	i3 = Postoffice::ImageAttachment.new(image_uid: uid1)
	i3b = Postoffice::ImageAttachment.new(image_uid: uid2)
  mail3 = Postoffice::Mail.create!({
		correspondents: [f3, t3],
		attachments: [n3, i3]
  })

	mail3.mail_it

	f4 = Postoffice::FromPerson.new(person_id: evan.id)
	t4 = Postoffice::ToPerson.new(person_id: demo.id)
	n4 = Postoffice::Note.new(content: "Thanks for checking out the app! Looking forward to getting your feedback.")
	mail4 = Postoffice::Mail.create!({
		correspondents: [f4, t4],
		attachments: [n4]
	})

	mail4.mail_it
	mail4.deliver

	f5 = Postoffice::FromPerson.new(person_id: demo.id)
	t5 = Postoffice::ToPerson.new(person_id: evan.id)
	n5 = Postoffice::Note.new(content: "Can't wait to receive a few more Slowposts!")
	i5 = Postoffice::ImageAttachment.new(image_uid: uid1)
	mail5 = Postoffice::Mail.create!({
		correspondents: [f5, t5],
		attachments: [n5, i5]
	})

	mail5.mail_it

	f6 = Postoffice::FromPerson.new(person_id: demo.id)
	t6 = Postoffice::ToPerson.new(person_id: person.id)
	n6 = Postoffice::Note.new(content: "Now I have to get to writing.")
	i6 = Postoffice::ImageAttachment.new(image_uid: uid1)
	mail6 = Postoffice::Mail.create!({
		correspondents: [f6, t6],
		attachments: [n6, i6]
	})

	mail6.mail_it
	mail6.scheduled_to_arrive = Time.now
	mail6.save

	Postoffice::ConversationService.initialize_conversations_for_all_mail

end

task :setup_minimal_demo_data do
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
	Postoffice::Conversation.delete_all
	Postoffice::QueueItem.delete_all

	Postoffice::Person.create!({
			username: "postman",
			email: "postman@slowpost.me",
			given_name: "Slowpost",
			family_name: "Postman",
			phone: "5554441234",
			address1: nil,
			city: nil,
			state: nil,
			zip: nil
		})
end

task :notify_recipients do
  puts "Notifying recipients for #{ENV['RACK_ENV']} environment"
  Postoffice::MailService.deliver_mail_and_notify_correspondents ENV["POSTMARK_API_KEY"]
end

task :test_notification do
  puts "Sending test notification for #{ENV['RACK_ENV']} environment"
  people = Postoffice::Person.where(username: "evan.waters")
  notifications = Postoffice::NotificationService.create_notification_for_people people, "Test notification", "Test"
  puts "Sending notifications: #{notifications}"
  APNS.send_notifications(notifications)
end

task :test_notification_of_recipients do
	f = Postoffice::Person.find_by(username: "postman")
	t = Postoffice::Person.find_by(username: "evan.waters")
	fp = Postoffice::FromPerson.new(person_id: f.id)
	tp = Postoffice::ToPerson.new(person_id: t.id)
	te = Postoffice::Email.new(email: "evan@slowpost.me")
	n = Postoffice::Note.new(content: "Did ya get this?")

	image = File.open('spec/resources/image1.jpg')
	uid = Dragonfly.app.store(image.read, 'name' => 'image1.jpg')
	image.close
	i = Postoffice::ImageAttachment.new(image_uid: uid)

	mail = Postoffice::Mail.create!({
		correspondents: [fp, tp, te],
		attachments: [n, i]
	})
	mail.mail_it
	mail.arrive_now

	Postoffice::MailService.deliver_mail_and_notify_correspondents ENV["POSTMARK_API_KEY"]
end

task :test_notification_of_sender do

	f2 = Postoffice::Person.find_by(username: "evan.waters")
	t2 = Postoffice::Person.find_by(username: "postman")
	fp2 = Postoffice::FromPerson.new(person_id: f2.id)
	tp2 = Postoffice::ToPerson.new(person_id: t2.id)
	n2 = Postoffice::Note.new(content: "Yes, I did!")

	image2 = File.open('spec/resources/image1.jpg')
	uid2 = Dragonfly.app.store(image2.read, 'name' => 'image2.jpg')
	image2.close
	i2 = Postoffice::ImageAttachment.new(image_uid: uid2)

	mail2 = Postoffice::Mail.create!({
		correspondents: [fp2, tp2],
		attachments: [n2, i2]
	})
	mail2.mail_it
	mail2.arrive_now

	Postoffice::MailService.deliver_mail_and_notify_correspondents ENV["POSTMARK_API_KEY"]
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

task :test_email do

	if ENV["RACK_ENV"] == "production"
		puts "Cannot run this task on production environment"
		return nil
	end

	Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])
	Mongoid.logger.level = Logger::INFO
	Mongo::Logger.logger.level = Logger::INFO

	image = File.open('spec/resources/birthday.jpg')
	uid = Dragonfly.app.store(image.read, 'name' => 'image1.jpg')
	image.close

	person = Postoffice::Person.find_by(username:"demo")
	f = Postoffice::FromPerson.new(person_id: person.id)
	t1 = Postoffice::Email.new(email: "bigedubs44@yahoo.com")
	t2 = Postoffice::Email.new(email: "evan@slowpost.me")
	t3 = Postoffice::Email.new(email: "evan.waters@gmail.com")
	n = Postoffice::Note.new(content: "Can't wait to celebrate Slowpost's birthday!")
	i = Postoffice::ImageAttachment.new(image_uid: uid)
	mail = Postoffice::Mail.create!({
		correspondents: [f, t1, t2, t3],
		attachments: [n, i],
		scheduled_to_arrive: Time.now,
		type: "SCHEDULED"
	})

	mail.mail_it

	Postoffice::MailService.deliver_mail_and_notify_correspondents ENV["POSTMARK_API_KEY"]

end

task :test_password_reset_email do
	person = Postoffice::Person.find_by(username: "evan.waters")
	Postoffice::AuthService.send_password_reset_email person, ENV["POSTMARK_API_KEY"]
end

task :test_email_validation do
	person = Postoffice::Person.find_by(username: "evan.waters")
	Postoffice::AuthService.send_email_validation_email person, ENV["POSTMARK_API_KEY"]
end

task :manual_email_validation, [:username] do |t, args|
	person = Postoffice::Person.find_by(username: args[:username])
	Postoffice::AuthService.send_email_validation_email person, ENV["POSTMARK_API_KEY"]
end

task :test_preview_email do
	if ENV["RACK_ENV"] == "production"
		puts "Cannot run this task on production environment"
		return nil
	end

	Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])
	Mongoid.logger.level = Logger::INFO
	Mongo::Logger.logger.level = Logger::INFO

	image = File.open('spec/resources/birthday.jpg')
	uid = Dragonfly.app.store(image.read, 'name' => 'image1.jpg')
	image.close

	person = Postoffice::Person.find_by(username:"evan.waters")
	f = Postoffice::FromPerson.new(person_id: person.id)
	t1 = Postoffice::Email.new(email: "bigedubs44@yahoo.com")
	t2 = Postoffice::Email.new(email: "evan@slowpost.me")
	t3 = Postoffice::Email.new(email: "evan.waters@gmail.com")
	n = Postoffice::Note.new(content: "Can't wait to celebrate Slowpost's birthday!")
	i = Postoffice::ImageAttachment.new(image_uid: uid)
	mail = Postoffice::Mail.create!({
		correspondents: [f, t1, t2, t3],
		attachments: [n, i],
		scheduled_to_arrive: Time.now,
		type: "SCHEDULED"
	})

	mail.mail_it
	mail.send_preview_email ENV["POSTMARK_API_KEY"]

end

task :get_admin_token do
	puts Postoffice::AuthService.get_admin_token
end

task :mark_token_as_invalid, [:token] do |t, args|
	token = Postoffice::Token.find_or_create_by(value: args[:token])
	token.mark_as_invalid
end

task :mark_token_as_valid, [:token] do |t, args|
	token = Postoffice::Token.find_or_create_by(value: args[:token])
	token.mark_as_valid
end

task :manual_notification, [:message, :username_list] do |t, args|
	usernames=args[:username_list].split(' ')
	notifications = []
	usernames.each do |username|
		person = Postoffice::Person.where(username: username).first
		if person && person.device_token != nil
			notifications << APNS::Notification.new(person.device_token, alert: args[:message], badge: nil, sound: 'default', other: {type: "Manual"})
		end
	end
	APNS.send_notifications(notifications)
end

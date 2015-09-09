require_relative '../../spec_helper'

describe Postoffice::MailService do

	before do

		@person1 = create(:person, username: random_username)
		@person2 = create(:person, username: random_username)
		@person3 = create(:person, username: random_username)

		@mail1 = create(:mail, from: @person1.username, to: @person2.username)
		@mail2 = create(:mail, from: @person1.username, to: @person2.username)
		@mail3 = create(:mail, from: @person3.username, to: @person1.username)

		@expected_attrs = attributes_for(:mail)

	end

	describe 'create mail' do

		before do
			data = Hash["to", @person2.username, "content", @expected_attrs[:content]]
			@mail4 = Postoffice::MailService.create_mail @person1.id, data
		end

		it 'must create a new piece of mail' do
			@mail4.must_be_instance_of Postoffice::Mail
		end

		it 'must store the person it is from' do
			@mail4.from.must_equal @person1.username
		end

		it 'must store person it is to' do
			@mail4.to.must_equal @person2.username
		end

		it 'must store the content' do
			@mail4.content.must_equal @expected_attrs[:content]
		end

		it 'must have a default status of "DRAFT"' do
			@mail4.status.must_equal 'DRAFT'
		end

		it 'must have a default type of "STANDARD"' do
			@mail4.type.must_equal 'STANDARD'
		end

	end

	describe 'create mail with image' do

		before do
			image = File.open('spec/resources/image2.jpg')
			@uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
			image.close

			data = Hash["to", @person2.username, "content", @expected_attrs[:content], "image_uid", @uid]
			@mail4 = Postoffice::MailService.create_mail @person1.id, data
		end

		it 'must add a Dragonfly attachment for the mail capable of getting the image name' do
			@mail4.image.name.must_equal 'image2.jpg'
		end

		it 'must be able to return the mime-type' do
			@mail4.image.mime_type.must_equal "image/jpeg"
		end

		it 'must add a thumbnail' do
			@mail4.thumbnail.mime_type.must_equal "image/jpeg"
		end

		it 'must compress the thumbnail to a height of 96 px' do
			@mail4.thumbnail.height.must_equal 96
		end

	end

	describe 'schedule when mail will arrive' do

		describe 'set_scheduled_to_arrive' do

			before do
				@mail_hash = Hash[from: "person", to: "another person", content: "what is up"]
				@data = Hash["scheduled_to_arrive", @scheduled_to_arrive]
				Postoffice::MailService.set_scheduled_to_arrive @mail_hash, @data
			end

			it 'must set the date that the mail is scheduled_to_arrive' do
				@mail_hash[:scheduled_to_arrive].must_equal @data["scheduled_to_arrive"]
			end

			it 'must set the type to SCHEDULED' do
				@mail_hash[:type].must_equal "SCHEDULED"
			end

		end

		describe 'call this method when creating mail' do

			before do
				@scheduled_to_arrive = Time.now + 5.days
				data = Hash["to", @person2.username, "content", @expected_attrs[:content], "scheduled_to_arrive", @scheduled_to_arrive]
				@scheduled_mail = Postoffice::MailService.create_mail @person1.id, data
			end

			it 'must have the date and time it is scheduled_to_arrive' do
				@scheduled_mail.scheduled_to_arrive.must_equal @scheduled_to_arrive
			end

			it 'must have type "SCHEDULED"' do
				@scheduled_mail.type.must_equal "SCHEDULED"
			end

		end

	end

	describe 'include delivery options' do

		describe 'invalid delivery options' do

			it 'must return false if the delivery options are valid' do
				Postoffice::MailService.invalid_delivery_options?(["EMAIL"]).must_equal false
			end

			it 'must return true if the delivery options are invalid' do
				Postoffice::MailService.invalid_delivery_options?(["EMAIL", "SLOWPOST", "STAGECOACH"]).must_equal true
			end

		end

		describe 'set delivery options' do

			before do
				@mail_hash = Hash[from: "person", to: "another person", content: "what is up"]
			end

			it 'must set the delivery options if they are given' do
				data = Hash["delivery_options", ["EMAIL"]]
				Postoffice::MailService.set_delivery_options @mail_hash, data
				@mail_hash[:delivery_options].must_equal ["EMAIL"]
			end

			it 'must raise an error if the options are invalid' do
				data = Hash["delivery_options", ["STAGECOACH"]]
				assert_raises RuntimeError do
					Postoffice::MailService.set_delivery_options @mail_hash, data
				end
			end

			describe 'call this method when creating mail' do

				before do
					@delivery_options = ["SLOWPOST", "EMAIL"]
					data = Hash["to", @person2.username, "content", @expected_attrs[:content], "delivery_options", @delivery_options]
					@mail_with_opts = Postoffice::MailService.create_mail @person1.id, data
				end

				it 'must set the delivery options' do
					@mail_with_opts[:delivery_options].must_equal @delivery_options
				end

			end

		end

		describe 'validate the ability to send email to a recipient' do

			describe 'validate email address' do

				it 'must return true if the email address is invalid' do
					Postoffice::MailService.invalid_email?("@foo").must_equal true
				end

				it 'must return true if the email address is nil' do
					Postoffice::MailService.invalid_email?(nil).must_equal true
				end

				it 'must return false if the email address is valid' do
					Postoffice::MailService.invalid_email?("test@test.com").must_equal false
				end

			end

			it 'must raise an error if the recipient is a Slowpost user and that person does not have a valid email address' do
				person = create(:person, username: random_username, email: "foo")
				mail_hash = Hash[to: person.username, content: "Hey", delivery_options: ["EMAIL"]]
				assert_raises RuntimeError do
					Postoffice::MailService.validate_ability_to_send_email_to_recipient mail_hash
				end
			end

			it 'must not raise an error if the recipient is Slowpost User a person who has a valid email address' do
				person = create(:person, username: random_username, email: "foo@test.com")
				mail_hash = Hash[to: person.username, content: "Hey", delivery_options: ["EMAIL"]]
				Postoffice::MailService.validate_ability_to_send_email_to_recipient mail_hash
			end

			it 'must raise an error if the to field is not a Slowpost User and is not a valid email address' do
				mail_hash = Hash[to: "foo", content: "Hey", delivery_options: ["EMAIL"]]
				assert_raises RuntimeError do
					Postoffice::MailService.validate_ability_to_send_email_to_recipient mail_hash
				end
			end

			it 'must not raise an error if the to field is a valid email address' do
				mail_hash = Hash[to: "foo@test.com", content: "Hey", delivery_options: ["EMAIL"]]
				Postoffice::MailService.validate_ability_to_send_email_to_recipient mail_hash
			end

			describe 'call this method when creating mail' do

				it 'must raise an error if the mail cannot be delivered by email' do
					data = Hash["to", "foo", "content", @expected_attrs[:content], "delivery_options", ["EMAIL"]]
					assert_raises RuntimeError do
						Postoffice::MailService.create_mail @person1.id, data
					end
				end

				it 'must not raise an error if delivery options are not specified' do
					data = Hash["to", @person2.username, "content", @expected_attrs[:content]]
					Postoffice::MailService.create_mail @person1.id, data
				end

				it 'must not raise an error if delivery options do not include email' do
					person = create(:person, username: random_username, email: "foo")
					data = Hash["to", @person2.username, "content", @expected_attrs[:content], "delivery_options", ["SLOWPOST"]]
					Postoffice::MailService.create_mail @person1.id, data
				end

			end


		end

	end

	describe 'ensure mail arrives in order in which it was sent' do
		before do
			@personA = create(:person, username: random_username)
			@personB = create(:person, username: random_username)

			@mailA = create(:mail, from: @personA.username, to: @personB.username)
			@mailB = create(:mail, from: @personA.username, to: @personB.username)

			@mailA.mail_it
			@mailB.mail_it
		end

		it 'must make the arrival date of a mail at least 5 minutes after the latest arriving mail, if the former mail was sent later' do
			@mailA.scheduled_to_arrive = Time.now + 4.days
			@mailA.save
			Postoffice::MailService.ensure_mail_arrives_in_order_it_was_sent @mailB
			updated_mail_record = Postoffice::Mail.find(@mailB.id)
			updated_mail_record.scheduled_to_arrive.to_i.must_equal (@mailA.scheduled_to_arrive + 5.minutes).to_i
		end

		it 'must leave the mail arrival date as is if it is already scheduled to arrive later than the other mail' do
			@mailA.scheduled_to_arrive = Time.now
			@mailA.save
			original_scheduled_date = @mailB.scheduled_to_arrive
			Postoffice::MailService.ensure_mail_arrives_in_order_it_was_sent @mailB
			updated_mail_record = Postoffice::Mail.find(@mailB.id)
			updated_mail_record.scheduled_to_arrive.to_i.must_equal original_scheduled_date.to_i
		end

		it 'must ignore other mail if it does not have a type of "STANDARD"' do
			@mailA.scheduled_to_arrive = Time.now + 4.days
			@mailA.type = "SCHEDULED"
			@mailA.save
			original_scheduled_date = @mailB.scheduled_to_arrive
			Postoffice::MailService.ensure_mail_arrives_in_order_it_was_sent @mailB
			updated_mail_record = Postoffice::Mail.find(@mailB.id)
			updated_mail_record.scheduled_to_arrive.to_i.must_equal original_scheduled_date.to_i
		end

	end

	describe 'get mail' do

		it 'must get all of the mail if no parameters are given' do
			num_mail = Postoffice::Mail.count
			mail = Postoffice::MailService.get_mail
			mail.length.must_equal num_mail
		end

		it 'must filter the records by from when it is passed in as a parameter' do
			num_mail = Postoffice::Mail.where({from: @person1.username}).count
			params = Hash[:from, @person1.username]
			mail = Postoffice::MailService.get_mail params
			mail.length.must_equal num_mail
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_mail = Postoffice::Mail.where({from: @person1.username, to: @person2.username}).count
			params = Hash[:from, @person1.username, :to, @person2.username]
			mail = Postoffice::MailService.get_mail params
			mail.length.must_equal num_mail
		end

	end

	describe 'mailbox' do

		before do

			@mail1.mail_it
			@mail1.make_it_arrive_now

			@mail2.mail_it

			@params = Hash[:id, @person2.id]
		end

		describe 'get mailbox' do

			before do
				@mailbox = Postoffice::MailService.mailbox(@params)
			end

			it 'must get mail that has arrived' do
				@mailbox.to_s.must_include @mail1.id.to_s
			end

			it 'must not show mail that has not arrived' do
				@mailbox.to_s.match(/#{@mail2.id.to_s}/).must_equal nil
			end

			it 'must have updated the delivery status if necessary' do
				Postoffice::Mail.find(@mail1.id).status.must_equal "DELIVERED"
			end

		end

		describe 'get only mailbox updates since a datetime' do

			before do
				@mail4 = create(:mail, from: @person1.username, to: @person2.username)
				@mail4.mail_it
				@mail4.make_it_arrive_now

				@params[:updated_at] = { "$gt" => @mail2.updated_at }
			end

			it 'must get mailbox records that were updated after the date specified' do
				number_returned = Postoffice::MailService.mailbox(@params).count
				expected_number = Postoffice::Mail.where({to: @person2.username, scheduled_to_arrive: { "$lte" => Time.now }, updated_at: { "$gt" => @mail2.updated_at }}).count
				number_returned.must_equal expected_number
			end

		end

		describe 'filter by from person' do

			before do
				@exclude_mail = create(:mail, from: @person3.username, to: @person2.username)
				@exclude_mail.mail_it
				@exclude_mail.make_it_arrive_now

				@params[:conversation_username] = @person1.username

				@mailbox = Postoffice::MailService.mailbox(@params)
			end

			it 'must return mail from person 1' do
				filtered_mail = @mailbox.select {|mail| mail[:from] == @person1.username}
				assert_operator filtered_mail.count, :>=, 1
			end

			it 'must not return mail from person 2' do
				filtered_mail = @mailbox.select {|mail| mail[:from] == @person3.username}
				filtered_mail.count.must_equal 0
			end

		end

		describe 'handle delivery options' do

			before do
				@exclude_mail = create(:mail, from: @person1.username, to: @person2.username, delivery_options: ["EMAIL"])
				@exclude_mail.mail_it
				@exclude_mail.make_it_arrive_now

				@include_mail = create(:mail, from: @person1.username, to: @person2.username, delivery_options: ["EMAIL", "SLOWPOST"])
				@include_mail.mail_it
				@include_mail.make_it_arrive_now

				@mailbox = Postoffice::MailService.mailbox(@params)
			end

			it 'must include mail that has "SLOWPOST" as a delivery option' do
				include_mail_document = Postoffice::Mail.find(@include_mail.id).as_document
				@mailbox.select {|mail| mail["_id"] == include_mail_document["_id"]}.count.must_equal 1
			end

			it 'must not include mail that does not have "SLOWPOST" as a delivery option' do
				exclude_mail_document = Postoffice::Mail.find(@exclude_mail.id).as_document
				@mailbox.select {|mail| mail["_id"] == exclude_mail_document["_id"]}.count.must_equal 0
			end

		end

	end

	describe 'outbox' do

		before do

			@mail1.mail_it

			@params1 = Hash[:id, @person1.id]
			@params2 = Hash[:id, @person2.id]

			@mail1.make_it_arrive_now
		end

		describe 'get outbox' do

			before do
				@outbox = Postoffice::MailService.outbox(@params1)
			end

			it 'must get mail that has been sent by the user' do
				@outbox.to_s.must_include @mail1.id.to_s
			end

			it 'must not get mail that has been sent by another user' do
				Postoffice::MailService.outbox(@params2).to_s.match(/#{@mail1.id.to_s}/).must_equal nil
			end

		end

		describe 'get only outbox updates since a datetime' do

			before do
				@mail4 = create(:mail, from: @person1.username, to: @person2.username)
				@mail4.mail_it
				@mail4.make_it_arrive_now

				@params1[:updated_at] = { "$gt" => @mail1.updated_at }
			end

			it 'must get outbox records that were updated after the date specified' do
				number_returned = Postoffice::MailService.outbox(@params1).count
				expected_number = Postoffice::Mail.where({from: @person1.username, updated_at: { "$gt" => @mail1.updated_at }}).count
				number_returned.must_equal expected_number
			end

		end

		describe 'filter by to person' do

			before do
				@exclude_mail = create(:mail, from: @person1.username, to: @person3.username)
				@exclude_mail.mail_it

				@params1[:conversation_username] = @person2.username

				@outbox = Postoffice::MailService.outbox(@params1)
			end

			it 'must return mail to person 2' do
				filtered_mail = @outbox.select {|mail| mail[:to] == @person2.username}
				assert_operator filtered_mail.count, :>=, 1
			end

			it 'must not return mail to person 3' do
				filtered_mail = @outbox.select {|mail| mail[:to] == @person3.username}
				filtered_mail.count.must_equal 0
			end

		end

	end

	describe 'get conversation metadata' do

		before do
			@mail1.mail_it
			@mail1.make_it_arrive_now
			@mail1.update_delivery_status
			@mail2.mail_it
			@mail2.make_it_arrive_now
			@mail2.update_delivery_status
			@another_mail = create(:mail, from: @person2.username, to: @person1.username)
			@another_mail.mail_it

			@not_slowpost_mail = create(:mail, from: @person1.username, to: @person2.username, delivery_options: ["EMAIL"])
			@not_slowpost_mail.mail_it
			@not_slowpost_mail.make_it_arrive_now
			@not_slowpost_mail.update_delivery_status

			@params = Hash[:id, @person2.id]
			@person2_penpals = Postoffice::MailService.get_contacts @params
			@conversation_metadata = Postoffice::MailService.conversation_metadata @params
		end

		it 'must return an array of Hashes' do
			@conversation_metadata[0].must_be_instance_of Hash
		end

		it 'it must return a Hash for each penpal' do
			@conversation_metadata.count.must_equal @person2_penpals.count
		end

		describe 'the metadata' do

			before do
				@metadata_for_person1 = @conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
			end

			it 'must include the username' do
				@metadata_for_person1[:username].must_equal @person1.username
			end

			it 'must include the person name' do
				@metadata_for_person1[:name].must_equal @person2.name
			end

			describe 'unread mail' do

				it 'must include the number of unread mail that is to be delivered by SLOWPOST' do
					mailbox = Postoffice::MailService.mailbox @params
					num_unread = mailbox.select {|mail| mail[:status] != "READ" && mail[:from] == @person1.username && mail[:delivery_options].include?("SLOWPOST")}.count
					@metadata_for_person1[:num_unread].must_equal num_unread
				end

			end

			it 'must include the number of undelivered mail' do
				outbox = Postoffice::MailService.outbox @params
				num_undelivered = outbox.select {|mail| mail[:status] == "SENT" && mail[:to] == @person1.username}.count
				@metadata_for_person1[:num_undelivered].must_equal num_undelivered
			end

			it 'must include the datetime that the most recent mail was updated' do
				@another_mail.updated_at = Time.now + 5.seconds
				@another_mail.save
				conversation_metadata = Postoffice::MailService.conversation_metadata @params
				metadata_for_person1 = conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
				metadata_for_person1[:updated_at].to_i.must_equal @another_mail.updated_at.to_i
			end

			it 'must include the most recent status of a mail' do
				@another_mail.updated_at = Time.now + 5.seconds
				@another_mail.save
				conversation_metadata = Postoffice::MailService.conversation_metadata @params
				metadata_for_person1 = conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
				metadata_for_person1[:most_recent_status].must_equal @another_mail.status
			end

			it 'must include the most recent sender of a mail' do
				@another_mail.updated_at = Time.now + 5.seconds
				@another_mail.save
				conversation_metadata = Postoffice::MailService.conversation_metadata @params
				metadata_for_person1 = conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
				metadata_for_person1[:most_recent_sender].must_equal @another_mail.from
			end

		end

		describe 'get only recent metadata' do

			before do
				recently_updated_mail = create(:mail, from: @person2.username, to: @person3.username)
				recently_updated_mail.mail_it
				recently_updated_mail.updated_at = Time.now + 5.minutes
				recently_updated_mail.save

				one_more_mail = create(:mail, from: @person2.username, to: @person3.username)
				one_more_mail.mail_it

				another_mail = create(:mail, from: @person3.username, to: @person2.username)
				another_mail.mail_it
				another_mail.make_it_arrive_now
				another_mail.update_delivery_status

				params = Hash[:id, @person2.id, :updated_at, { "$gt" => Time.now + 4.minutes }]
				@conversation_metadata = Postoffice::MailService.conversation_metadata params

			end

			it 'must only include people who sent mail or received mail after the date' do
				@conversation_metadata.count.must_equal 1
			end

			it 'must include the total number of unread mail, not just the mail unread since the date' do
				@conversation_metadata[0][:num_unread].must_equal 1
			end

			it 'must include the total number of undelivered mail, not just the mail undelivered since the date' do
				@conversation_metadata[0][:num_undelivered].must_equal 2
			end

		end

	end

	describe 'conversation' do

		before do
			@mail1.mail_it
			@mail1.make_it_arrive_now

			@mail2.mail_it

			@include_mail = create(:mail, from: @person2.username, to: @person1.username)

			@exclude_mail1 = create(:mail, from: @person2.username, to: @person3.username)
			@exclude_mail2 = create(:mail, from: @person3.username, to: @person2.username)
			@exclude_mail2.mail_it
			@exclude_mail2.make_it_arrive_now

			@params = Hash[:id, @person2.id, :conversation_id, @person1.id]
			@conversation = Postoffice::MailService.conversation @params
		end

		it 'must include mail from person2 to person 1' do
			filtered_mail = @conversation.select {|mail| mail[:from] == @person2.username && mail[:to] == @person1.username}
			assert_operator filtered_mail.count, :>=, 1
		end

		it 'must include mail from person 2 to person 1' do
			filtered_mail = @conversation.select {|mail| mail[:from] == @person1.username && mail[:to] == @person2.username}
			assert_operator filtered_mail.count, :>=, 1
		end

		it 'must not include mail from or to person 3' do
			filtered_mail = @conversation.select {|mail| mail[:to] == @person3.username || mail[:from] == @person3.username}
			filtered_mail.count.must_equal 0
		end

		it 'must sort the mail in descending order based on the date it was created' do
			@mail1.created_at = Time.now - 5.days
			sorted_conversation = Postoffice::MailService.conversation @params
			sorted_conversation.pop[:_id].to_s.must_equal @mail1.id.to_s
		end

	end

	describe 'find mail to deliver' do

		before do

			@mail1.mail_it
			@mail1.make_it_arrive_now
			@mail2.mail_it

			@mail_to_deliver = Postoffice::MailService.find_mail_to_deliver
		end

		it 'must return mail that is scheduled to arrive in the past' do
			assert_operator @mail_to_deliver[0].scheduled_to_arrive, :<=, Time.now
		end

		it 'must return mail with status of SENT' do
			@mail_to_deliver[0].status.must_equal "SENT"
		end

		it 'must not return any mail that is not scheduled to arrive in the past' do
			not_scheduled_to_arrive_yet = @mail_to_deliver.select{|mail| mail.scheduled_to_arrive >= Time.now}
			not_scheduled_to_arrive_yet.length.must_equal 0
		end

		it 'must not return any mail with status other than SENT' do
			wrong_status = @mail_to_deliver.select{|mail| mail.status != "SENT"}
			wrong_status.length.must_equal 0
		end

	end

	describe 'deliver mail' do

		before do

			@mail1.mail_it
			@mail1.make_it_arrive_now
			@mail2.mail_it

			@mail_to_deliver = Postoffice::MailService.find_mail_to_deliver

			Postoffice::MailService.deliver_mail @mail_to_deliver

		end

		it 'must update the status of the mail to DELIVERED' do
			@mail_to_deliver[0].status.must_equal "DELIVERED"
		end

		it 'must not leave any mail in status of SENT' do
			undelivered_mail = @mail_to_deliver.select{|mail| mail.status != "DELIVERED"}
			undelivered_mail.length.must_equal 0
		end

	end

	describe 'find people to notify' do

		before do
			@mail1.mail_it
			@mail1.make_it_arrive_now
			@mail2.mail_it
			@mail2.make_it_arrive_now

			@mails = [@mail1, @mail2]
			@people_to_notify = Postoffice::MailService.people_to_notify @mails
		end

		it 'must return people that are receiving the mail' do
			assert_operator @people_to_notify.select{|person| person.username == @person2.username}.length, :>=, 1
		end

		it 'must return only one instance of each person' do
			@people_to_notify.select{|person| person.username == @person2.username}.length.must_equal 1
		end

		it 'must not return people if the mail that has been sent to them is not supposed to be delivered via SLOWPOST' do
			@exclude_person = create(:person, username: random_username)
			exclude_mail = create(:mail, from: @person1.username, to: @exclude_person.username, delivery_options: ["EMAIL"])
			exclude_mail.mail_it
			exclude_mail.make_it_arrive_now

			@mails << exclude_mail
			notified_people = Postoffice::MailService.people_to_notify @mails

			notified_people.select{|person| person.username ==  @exclude_person.username}.count.must_equal 0
		end

	end

	describe 'find emails to send' do

		before do
			@email_mail = create(:mail, from: @person1.username, to: "test@test.com", content: "Yo", delivery_options: ["EMAIL"])
			@email_mail.mail_it
			@email_mail.make_it_arrive_now

			@mail1.mail_it
			@mail1.make_it_arrive_now

			@emails_to_send = Postoffice::MailService.find_emails_to_send
		end

		it 'must find mail that has arrived and has an EMAIL delivery option' do
			@emails_to_send.select{|mail| mail.id == @email_mail.id}.count.must_equal 1
		end

		it 'must not include mail that does not have an EMAIL delivery option' do
			@emails_to_send.select{|mail| mail.id == @mail1.id}.count.must_equal 0
		end

	end

	describe 'deliver mail and notify recipients' do

		before do
			@mail1.mail_it
			@mail1.make_it_arrive_now
			@mail2.mail_it
			@mail2.make_it_arrive_now

			Postoffice::MailService.deliver_mail_and_notify_recipients
		end

		it 'must update the status of the mail to "DELIVERED"' do
			mail = Postoffice::Mail.find(@mail1.id)
			mail.status.must_equal "DELIVERED"
		end

		describe 'send notifications' do
			#TO DO: Figure out how to test that APNS notifications were actually sent
		end

		describe 'send emails' do

			before do
				@email_mail = build(:mail, from: @person1.username, to: "test@test.com", delivery_options: ["EMAIL, SLOWPOST"])
				@email_mail.mail_it
				@email_mail.make_it_arrive_now
			end

			it 'must send the mail without any errors' do
				Postoffice::MailService.deliver_mail_and_notify_recipients
			end

		end

	end

	describe 'get contacts' do

		#Touching mail to create associated mail objects in database
		before do
			@mail1.mail_it
			@mail2.mail_it
			@mail3.mail_it

			@params = Hash[:id, @person1.id.to_s]
		end

		describe 'get users the person has sent mail to' do

			before do
				@recipients = Postoffice::MailService.get_people_who_received_mail_from @params
			end

			it 'must return an array of people' do
				@recipients[0].must_be_instance_of Postoffice::Person
			end

			it 'must include every user who has received mail from this person' do
				sent_to = []
				Postoffice::Mail.where(from: @person1.username).each do |mail|
					sent_to << Postoffice::Person.find_by(username: mail.to)
				end
				(@recipients.uniq - sent_to.uniq).must_equal []
			end

		end

		describe 'get records where mail was sent since a date' do

			before do
				another_mail = create(:mail, from: @person1.username, to: @person3.username)
				another_mail.updated_at = Time.now + 5.minutes
				another_mail.save
				@params[:updated_at] = { "$gt" => Time.now + 4.minutes }
				@recipients = Postoffice::MailService.get_people_who_received_mail_from @params
			end

			it 'must include people who sent mail to the user after the date specified' do
				@recipients.must_include @person3
			end

			it 'must not include people who sent mail to the user earlier than the date specified' do
				(@recipients.include? @person2).must_equal false
			end

		end

		describe 'get users the person has received mail from' do

			before do
				@mail3.make_it_arrive_now
				@mail3.update_delivery_status

				another_mail = create(:mail, from: @person2.username, to: @person1.username)
				another_mail.mail_it
				@senders = Postoffice::MailService.get_people_who_sent_mail_to @params
			end

			it 'must return an array of people' do
				@senders[0].must_be_instance_of Postoffice::Person
			end

			it 'must include every user who has sent mail to this person, if the mail has been delivered already' do
				received_from = []
				Postoffice::Mail.where(to: @person1.username).each do |mail|
					received_from << Postoffice::Person.find_by(username: mail.from)
				end
				(@senders.uniq - received_from.uniq).must_equal []
			end

			it 'must not include users who have sent mail to the person that has not been delivered' do
				@senders.include?(@person2).must_equal false
			end

		end

		describe 'get records where mail was sent since a date' do

			before do
				another_mail = create(:mail, from: @person2.username, to: @person1.username)
				another_mail.mail_it
				another_mail.make_it_arrive_now
				another_mail.update_delivery_status
				another_mail.updated_at = Time.now + 5.minutes
				another_mail.save
				@params[:updated_at] = { "$gt" => Time.now + 4.minutes }
				@senders = Postoffice::MailService.get_people_who_sent_mail_to @params
			end

			it 'must include people who sent mail to the user after the date specified' do
				@senders.must_include @person2
			end

			it 'must not include people who sent mail to the user earlier than the date specified' do
				(@senders.include? @person3).must_equal false
			end

		end

		it 'must return an array of bson documents' do
			contacts = Postoffice::MailService.get_contacts @params
			contacts[0].must_be_instance_of BSON::Document
		end

		it 'must create a unique list of all senders and recipients' do
			senders = Postoffice::MailService.get_people_who_sent_mail_to @params
			recipients = Postoffice::MailService.get_people_who_received_mail_from @params
			comparison_group = (senders + recipients).uniq
			comparison_group_as_documents = []
			comparison_group.each do |person|
				comparison_group_as_documents << person.as_document
			end

			contacts = Postoffice::MailService.get_contacts @params
			(contacts - comparison_group_as_documents).must_equal []
		end

	end

	describe 'send email' do

		describe 'get email address to send mail to' do

			it 'must return an email address for the recipient if it is valid' do
				person = create(:person, username: random_username, email: "test@test.com")
				mail = build(:mail, from: @person1.username, to: person.username, delivery_options: ["EMAIL"])
				Postoffice::MailService.get_email_to_send_mail_to(mail).must_equal person.email
			end

			it 'must return a valid email address if that is what the mail is addressed to' do
				mail = build(:mail, from: @person1.username, to: "test@test.com", delivery_options: ["EMAIL"])
				Postoffice::MailService.get_email_to_send_mail_to(mail).must_equal "test@test.com"
			end

			it 'must raise an error if the mail is addressed to a person and they do not have a valid email address' do
				person = create(:person, username: random_username, email: "foo")
				mail = build(:mail, from: @person1.username, to: person.username, delivery_options: ["EMAIL"])

				assert_raises RuntimeError do
					Postoffice::MailService.get_email_to_send_mail_to(mail)
				end
			end

			it 'must raise an error if the mail is addressed to an invalid valid email address' do
				mail = build(:mail, from: @person1.username, to: "foo", delivery_options: ["EMAIL"])
				assert_raises RuntimeError do
					Postoffice::MailService.get_email_to_send_mail_to(mail)
				end
			end

		end

		describe 'create hash for email based on mail contents' do

			before do
				@mail = build(:mail, from: @person1.username, to: "test@test.com", delivery_options: ["EMAIL"])
				@hash = Postoffice::MailService.create_email_hash @mail
			end

			it 'must be from the Postman email account' do
				@hash[:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
			end

			it 'must be to the correct email address' do
				@hash[:to].must_equal "test@test.com"
			end

			it 'must have a subject' do
				@hash[:subject].must_equal "You've received a Slowpost!"
			end

			it 'must have an html body' do
				@hash[:html_body].must_equal @mail.content
			end

			it 'must be configured to track opens' do
				@hash[:track_opens].must_equal true
			end

		end

		describe 'send a test email' do

			before do
				@email_hash = Hash[from: "postman@slowpost.me", to: "evan@slowpost.me", subject: "This is a test", html_body: "<strong>Hello</strong> Evan!", track_opens: false]
				@result = Postoffice::MailService.send_email @email_hash
			end

			it 'must not get an error' do
				@result[:error_code].must_equal 0
			end

			it 'must be sent to the right person' do
				@result[:to].must_equal @email_hash[:to]
			end

			it 'must have a unique id' do
				@result[:message_id].must_be_instance_of String
			end

			it 'must indicate that the test job was accpepted' do
				@result[:message].must_equal "Test job accepted"
			end

		end

		describe 'send email for a mail' do

			before do
				@mail = build(:mail, from: @person1.username, to: "test@test.com", delivery_options: ["EMAIL"])
				@result = Postoffice::MailService.send_email_for_mail @mail
			end

			it 'must not get an error' do
				@result[:error_code].must_equal 0
			end

		end

	end

end

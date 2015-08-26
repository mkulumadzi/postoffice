require_relative '../../spec_helper'

describe Postoffice::MailService do

	Mongoid.load!('config/mongoid.yml')

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
			@mail2.save

			@params = Hash[:id, @person2.id]

			Postoffice::MailService.mailbox(@params)

		end

		it 'must get mail that has arrived' do
			Postoffice::MailService.mailbox(@params).to_s.must_include @mail1.id.to_s
		end

		it 'must not show mail that has not arrived' do
			Postoffice::MailService.mailbox(@params).to_s.match(/#{@mail2.id.to_s}/).must_equal nil
		end

		it 'must have updated the delivery status if necessary' do
			Postoffice::Mail.find(@mail1.id).status.must_equal "DELIVERED"
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

	end

	describe 'outbox' do

		before do

			@mail1.mail_it

			@params1 = Hash[:id, @person1.id]
			@params2 = Hash[:id, @person2.id]

			@mail1.make_it_arrive_now
			Postoffice::MailService.outbox(@params1)
		end

		it 'must get mail that has been sent by the user' do
			Postoffice::MailService.outbox(@params1).to_s.must_include @mail1.id.to_s
		end

		it 'must not get mail that has been sent by another user' do
			Postoffice::MailService.outbox(@params2).to_s.match(/#{@mail1.id.to_s}/).must_equal nil
		end

		describe 'get only mailbox updates since a datetime' do

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
			mails = [@mail1, @mail2]
			@people_to_notify = Postoffice::MailService.people_to_notify mails
		end

		it 'must return people that are receiving the mail' do
			assert_operator @people_to_notify.select{|person| person.username = @person2.username}.length, :>=, 1
		end

		it 'must return only one instance of each person' do
			@people_to_notify.select{|person| person.username = @person2.username}.length.must_equal 1
		end

	end

	describe 'get contacts' do

		#Touching mail to create associated mail objects in database
		before do
			@mail1.mail_it
			@mail2.mail_it
			@mail3.mail_it
		end

		describe 'get users the person has sent mail to' do

			before do
				@recipients = Postoffice::MailService.get_people_who_received_mail_from @person1.username
			end

			it 'must return an array of people' do
				@recipients[0].must_be_instance_of Postoffice::Person
			end

			it 'must include every user who has received mail from this person' do

				not_in = 0

				Postoffice::Mail.where(from: @person1.id).each do |mail|
					person = Postoffice::Person.find_by(username: mail.to)

					if @recipients.include? person == false
						not_in += 1
					end

				end

				not_in.must_equal 0
			end

		end

		describe 'get users the person has received mail from' do

			before do
				@senders = Postoffice::MailService.get_people_who_sent_mail_to @person1.username
			end

			it 'must return an array of people' do
				@senders[0].must_be_instance_of Postoffice::Person
			end

			it 'must include every user who has sent mail to this person' do
				not_in = 0
				Postoffice::Mail.where(to: @person1.id).each do |mail|
					person = Postoffice::Person.find_by(username: mail.from)
					if @recipients.include? person == false
						not_in += 1
					end
				end
				not_in.must_equal 0
			end

		end

		it 'must return an array of bson documents' do
			contacts = Postoffice::MailService.get_contacts @person1.username
			contacts[0].must_be_instance_of BSON::Document
		end

		it 'must create a unique list of all senders and recipients' do

			senders = Postoffice::MailService.get_people_who_sent_mail_to @person1.username
			recipients = Postoffice::MailService.get_people_who_received_mail_from @person1.username

			comparison_group = []
			senders.concat(recipients).uniq.each do |person|
				comparison_group << person.as_document
			end

			contacts = Postoffice::MailService.get_contacts @person1.username

			not_in = 0
			comparison_group.each do |doc|
				if contacts.include? doc == false
					not_in += 1
				end
			end

			not_in.must_equal 0
		end

	end

end

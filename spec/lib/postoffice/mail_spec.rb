require_relative '../../spec_helper'

describe Postoffice::Mail do

	before do

		@person1 = create(:person, username: random_username)
		@person2 = create(:person, username: random_username)

		@mail1 = create(:mail, person: @person1, recipients: [build(:slowpost_recipient, person_id: @person2.id.to_s), build(:email_recipient, email: "test@test.com")])

		@expected_attrs = attributes_for(:mail)

	end

	describe 'create mail' do

		it 'must create a new piece of mail' do
			@mail1.must_be_instance_of Postoffice::Mail
		end

		it 'must store a reference to the person_id who sent it' do
			@mail1.from_person_id.must_be_instance_of BSON::ObjectId
		end

		it 'must store the person it is from' do
			@mail1.from.must_equal @expected_attrs[:from]
		end

		it 'must store person it is to' do
			@mail1.to.must_equal @expected_attrs[:to]
		end

		it 'must store the content' do
			@mail1.content.must_equal @expected_attrs[:content]
		end

		it 'must record the type of the mail' do
			@mail1.type.must_equal "STANDARD"
		end

		it 'must be able to store an email recipient' do
			assert_operator @mail1.recipients.select{|recipient| recipient.class == Postoffice::EmailRecipient}.count, :>=, 1
		end

		it 'must be able to store a Slowpost Recipient' do
			assert_operator @mail1.recipients.select{|recipient| recipient.class == Postoffice::SlowpostRecipient}.count, :>=, 1
		end

		# describe 'delivery options' do
		#
		# 	it 'must set the default delivery option to ["SLOWPOST"]' do
		# 		@mail1.delivery_options.must_equal ["SLOWPOST"]
		# 	end
		#
		# 	it 'must allow other values to be set' do
		# 		mail = build(:mail, delivery_options: ["EMAIL"])
		# 		mail.delivery_options.must_equal ["EMAIL"]
		# 	end
		#
		# end

		describe 'add mail image' do

			before do
				image = File.open('spec/resources/image2.jpg')
				@uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
				image.close

				@mail1.image = Dragonfly.app.fetch(@uid).apply
			end

			it 'must store the Dragonfly UID for the mail' do
				@mail1.image.name.must_equal 'image2.jpg'
			end

		end

		it 'must have a default status of "DRAFT"' do
			@mail1.status.must_equal 'DRAFT'
		end

	end

	describe 'query who the mail is from and to' do

		it 'must be able to find the person that the mail is from' do
			Postoffice::Mail.where(person: @person1).include?(@mail1).must_equal true
		end

		it 'must be able to find mail addressed to recipients by their id' do
			Postoffice::Mail.where("recipients.person_id" => @person2.id.to_s).include?(@mail1).must_equal true
		end

	end

	describe 'send mail' do

		before do
			@mail1.mail_it
		end

		it 'must calculate the number of days to arrive as 1 or more' do
			assert_operator @mail1.days_to_arrive, :>=, 1
		end

		it 'must calculate the number of days to arrive as 2 or less' do
			assert_operator @mail1.days_to_arrive, :<=, 2
		end

		it 'must generate an arrival date that is one or more days in the future' do
			diff = (@mail1.arrive_when - Time.now).round
			assert_operator diff, :>=, 1 * 86400
		end

		it 'must generate an arrival date that is less than 2 days away' do
			diff = (@mail1.arrive_when - Time.now).round
			assert_operator diff, :<=, 2 * 86400
		end

		it 'must have status of SENT' do
			@mail1.status.must_equal "SENT"
		end

		it 'must indicate that it was sent at the current date and time' do
			assert_operator (Time.now.to_i - @mail1.date_sent.to_i), :<=, 100
		end

		describe 'try to send mail that has already been sent' do

			it 'must throw an error' do
				assert_raises(ArgumentError) {
					@mail1.mail_it
				}
			end

		end

	end

	describe 'send mail that has alredy been scheduled' do

		before do
			@scheduled_to_arrive = Time.now + 5.days

			@scheduled_mail = build(:mail)
			@scheduled_mail.type = "SCHEDULED"
			@scheduled_mail.scheduled_to_arrive = @scheduled_to_arrive

			@scheduled_mail.mail_it
		end

		it 'must have status of "SENT"' do
			@scheduled_mail.status.must_equal "SENT"
		end

		it 'must still have the same date it was scheduled to arrive' do
			@scheduled_mail.scheduled_to_arrive.must_equal @scheduled_to_arrive
		end

	end

	describe 'deliver mail' do

		before do
			@mail1.mail_it
			@mail1.deliver
		end

		it 'must update the status to delivered' do
			@mail1.status.must_equal "DELIVERED"
		end

		it 'must set the date and time it was delivered to the current date and time' do
			assert_operator (Time.now.to_i - @mail1.date_delivered.to_i), :<=, 100
		end

		# it 'must not be scheduled to arrive in the future' do
		# 	assert_operator @mail1.scheduled_to_arrive, :<=, Time.now
		# end

	end

	# describe 'update delivery status' do
	#
	# 	before do
	# 		@mail1.mail_it
	# 		@mail1.make_it_arrive_now
	# 		@mail2.mail_it
	# 	end
	#
	# 	it 'must set the status of the mail to DELIVERED for mail that has arrived' do
	# 		@mail1.update_delivery_status
	# 		@mail1.status.must_equal "DELIVERED"
	# 	end
	#
	# 	it 'must not still list the mail status as SENT if the mail has not arrived yet' do
	# 		@mail2.update_delivery_status
	# 		@mail2.status.must_equal "SENT"
	# 	end
	#
	# 	it 'must not change mail that has been read back to delivered' do
	# 		@mail2.make_it_arrive_now
	# 		@mail2.update_delivery_status
	# 		@mail2.read
	# 		@mail2.update_delivery_status
	# 		@mail2.status.must_equal "READ"
	# 	end
	#
	# end

	# describe 'read mail' do
	#
	# 	before do
	# 		@mail1.mail_it
	# 		@mail1.make_it_arrive_now
	# 		@mail1.update_delivery_status
	#
	# 		@mail2.mail_it
	# 	end
	#
	# 	it 'must mark status of READ' do
	# 		@mail1.read
	# 		@mail1.status.must_equal "READ"
	# 	end
	#
	# 	it 'must throw an error if mail does not have status of DELIVERED' do
	# 		assert_raises(ArgumentError) {
	# 			@mail2.read
	# 		}
	# 	end
	#
	# end

end

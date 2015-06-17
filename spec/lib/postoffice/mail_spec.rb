require_relative '../../spec_helper'

describe SnailMail::Mail do

	Mongoid.load!('config/mongoid.yml')

	let ( :person1 ) {
		SnailMail::Person.create!(
			name: "Evan",
			username: SnailMail::Person.random_username
		)
	}

	let ( :person2 ) {
		SnailMail::Person.create!(
			name: "Neal",
			username: SnailMail::Person.random_username
		)
	}

	let ( :mail1 ) {
		SnailMail::Mail.create!(
			from: "#{person1.username}",
			to: "#{person2.username}",
			content: "What up",
			image: "SnailMail at the Beach.png"
		)	
	}

	let ( :mail2 ) {
		SnailMail::Mail.create!(
			from: "#{person1.username}",
			to: "#{person2.username}",
			content: "Hey how is it going?",
			image: "Default Card.png"
		)	
	}

	describe 'create mail' do

		it 'must create a new piece of mail' do
			mail1.must_be_instance_of SnailMail::Mail
		end

		it 'must store the person it is from' do
			mail1.from.must_equal "#{person1.username}"
		end

		it 'must store person it is to' do
			mail1.to.must_equal "#{person2.username}"
		end

		it 'must store the content' do
			mail1.content.must_equal 'What up'
		end

		it 'must store the image name' do
			mail1.image.must_equal 'SnailMail at the Beach.png'
		end

		it 'must have a default status of "DRAFT"' do
			mail1.status.must_equal 'DRAFT'
		end

	end

	describe 'use mail service to create mail' do

		before do
			data = JSON.parse '{"to": "' + person2.username + '", "content":"Hey how are you", "image": "Default Card.png"}'
			@mail = SnailMail::MailService.create_mail person1.id, data
		end

		it 'must create the mail' do
			@mail.must_be_instance_of SnailMail::Mail
		end

	end

	describe 'send mail' do

		before do
			mail1.mail_it
		end

		it 'must calculate the number of days to arrive as 3 or more' do
			assert_operator mail1.days_to_arrive, :>=, 3 
		end

		it 'must calculate the number of days to arrive as 5 or less' do
			assert_operator mail1.days_to_arrive, :<=, 5
		end

		it 'must generate an arrival date that is three or more days in the future' do
			diff = (mail1.arrive_when - Time.now).round
			assert_operator diff, :>=, 3 * 86400
		end

		it 'must generate an arrival date that is less than 5 days away' do
			diff = (mail1.arrive_when - Time.now).round
			assert_operator diff, :<=, 5 * 86400
		end

		it 'must have status of SENT' do
			mail1.status.must_equal "SENT"
		end

		describe 'try to send mail that has already been sent' do

			it 'must throw an error' do
				assert_raises(ArgumentError) {
					mail1.mail_it
				}
			end

		end

		## TO DO Figure out how to test this - the tests above work even if the record isn't saved
		# it 'must successfully save the record' do
		# end

	end

	describe 'deliver mail now' do

		before do
			mail1.mail_it
			mail1.deliver_now
		end

		it 'must not be scheduled to arrive in the future' do
			assert_operator mail1.scheduled_to_arrive, :<=, Time.now
		end

	end

	describe 'get mail' do

		it 'must get all of the mail if no parameters are given' do
			num_mail = SnailMail::Mail.count
			mail = SnailMail::MailService.get_mail
			mail.length.must_equal num_mail
		end

		it 'must filter the records by from when it is passed in as a parameter' do
			num_mail = SnailMail::Mail.where({from: "#{person1.username}"}).count
			params = Hash.new
			params[:from] = "#{person1.username}"
			mail = SnailMail::MailService.get_mail params
			mail.length.must_equal num_mail
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_mail = SnailMail::Mail.where({from: "#{person1.username}", to: "#{person2.username}"}).count
			params = Hash.new
			params[:from] = "#{person1.username}"
			params[:to] = "#{person2.username}"
			mail = SnailMail::MailService.get_mail params
			mail.length.must_equal num_mail
		end

		it 'must update the stutus of mail that has arrived' do
			mail1.mail_it
			mail1.deliver_now
			params = Hash.new
			params[:from] = "#{person1.username}"
			mails = SnailMail::MailService.get_mail params
			SnailMail::Mail.find(mail1.id).status.must_equal "DELIVERED"
		end

	end

	describe 'mailbox' do

		before do

			mail1.mail_it
			mail1.deliver_now

			mail2.mail_it
			mail2.save

			@params = Hash.new
			@params[:id] = person2.id

			SnailMail::MailService.mailbox(@params)

		end

		it 'must get mail that has arrived' do
			SnailMail::MailService.mailbox(@params).to_s.must_include mail1.id.to_s
		end

		it 'must not show mail that has not arrived' do
			SnailMail::MailService.mailbox(@params).to_s.match(/#{mail2.id.to_s}/).must_equal nil
		end

		it 'must have updated the delivery status if necessary' do
			SnailMail::Mail.find(mail1.id).status.must_equal "DELIVERED"
		end

	end

	describe 'outbox' do

		before do

			mail1.mail_it

			@params1 = Hash.new
			@params2 = Hash.new

			@params1[:id] = person1.id
			@params2[:id] = person2.id

			mail1.deliver_now
			SnailMail::MailService.outbox(@params1)
		end

		it 'must get mail that has been sent by the user' do
			SnailMail::MailService.outbox(@params1).to_s.must_include mail1.id.to_s
		end

		it 'must not get mail that has been sent by another user' do
			SnailMail::MailService.outbox(@params2).to_s.match(/#{mail1.id.to_s}/).must_equal nil
		end

		it 'must have updated the delivery status of the mail' do
			SnailMail::Mail.find(mail1.id).status.must_equal "DELIVERED"
		end

	end

	describe 'update delivery status' do


		before do

			mail1.mail_it
			mail1.deliver_now

			mail2.mail_it

		end

		it 'must set the status of the mail to DELIVERED for mail that has arrived' do
			mail1.update_delivery_status
			mail1.status.must_equal "DELIVERED"
		end

		it 'must not still list the mail status as SENT if the mail has not arrived yet' do
			mail2.update_delivery_status
			mail2.status.must_equal "SENT"
		end

	end

end
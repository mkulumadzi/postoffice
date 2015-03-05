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
			content: "What up"
		)	
	}

	let ( :mail2 ) {
		SnailMail::Mail.create!(
			from: "#{person1.username}",
			to: "#{person2.username}",
			content: "Hey"
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

		it 'must have a default status of "DRAFT"' do
			mail1.status.must_equal 'DRAFT'
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

	end

	describe 'mailbox' do

		before do

			mail1.mail_it

			mail1.scheduled_to_arrive = mail1.scheduled_to_arrive - 6 * 86400
			mail1.save

			mail2.mail_it
			mail2.save

			@params = Hash.new
			@params[:id] = person2.id

		end

		it 'must get mail that has arrived' do
			SnailMail::MailService.mailbox(@params).to_s.must_include mail1.id.to_s
		end

		it 'must not show mail that has not arrived' do
			SnailMail::MailService.mailbox(@params).to_s.match(/#{mail2.id.to_s}/).must_equal nil
		end

	end

end
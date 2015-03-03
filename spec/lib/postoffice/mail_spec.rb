require_relative '../../spec_helper'

describe SnailMail::Mail do

	Mongoid.load!('config/mongoid.yml')

	describe 'days to arrive' do

		it 'must generate a number between 3 and 5' do
			range = (3..5).to_a
			days_to_arrive = SnailMail::Mail.days_to_arrive
			range.include?(days_to_arrive).must_equal true
		end

	end

	describe 'create mail' do

		# To Do: Add validation to enforce from: and to: as foreign keys for people
		before do
			@person1 = SnailMail::Person.create!(
				name: "Evan",
				username: SnailMail::Person.random_username
			)

			@person2 = SnailMail::Person.create!(
				name: "Neal",
				username: SnailMail::Person.random_username
			)

			@mail = SnailMail::Mail.create!(
				from: "#{@person1.username}",
				to: "#{@person2.username}",
				content: "What up",
				status: "SENT",
				days_to_arrive: 3
			)
		end

		it 'must create a new piece of mail' do
			@mail.must_be_instance_of SnailMail::Mail
		end

		it 'must store the person it is from' do
			@mail.from.must_equal "#{@person1.username}"
		end

		it 'must store person it is to' do
			@mail.to.must_equal "#{@person2.username}"
		end

		it 'must store the content' do
			@mail.content.must_equal 'What up'
		end

		it 'must store the status as SENT' do
			@mail.status.must_equal 'SENT'
		end

		it 'must store the days to arrive' do
			@mail.days_to_arrive.must_equal 3
		end

	end

	describe 'get mail' do

		before do
			@person1 = SnailMail::Person.create!(
				name: "Evan",
				username: SnailMail::Person.random_username
			)

			@person2 = SnailMail::Person.create!(
				name: "Neal",
				username: SnailMail::Person.random_username
			)

			@mail = SnailMail::Mail.create!(
				from: "#{@person1.username}",
				to: "#{@person2.username}",
				content: "What up",
				status: "SENT",
				days_to_arrive: 3
			)
		end

		it 'must get all of the mail if no parameters are given' do
			num_mail = SnailMail::Mail.count
			mail = SnailMail::Mail.get_mail
			mail.length.must_equal num_mail
		end

		it 'must filter the records by from when it is passed in as a parameter' do
			num_mail = SnailMail::Mail.where({from: "#{@person1.username}"}).count
			params = Hash.new
			params[:from] = "#{@person1.username}"
			mail = SnailMail::Mail.get_mail params
			mail.length.must_equal num_mail
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_mail = SnailMail::Mail.where({from: "#{@person1.username}", to: "#{@person2.username}"}).count
			params = Hash.new
			params[:from] = "#{@person1.username}"
			params[:to] = "#{@person2.username}"
			mail = SnailMail::Mail.get_mail params
			mail.length.must_equal num_mail
		end

	end

end
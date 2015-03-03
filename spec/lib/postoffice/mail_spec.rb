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
			@mail = SnailMail::Mail.create!(
				from: "ewaters",
				to: "nwaters",
				content: "What up",
				status: "SENT",
				days_to_arrive: 3
			)
		end

		it 'must create a new piece of mail' do
			@mail.must_be_instance_of SnailMail::Mail
		end

		it 'must store the person it is from' do
			@mail.from.must_equal 'ewaters'
		end

		it 'must store person it is to' do
			@mail.to.must_equal 'nwaters'
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

		it 'must get all of the mail if no parameters are given' do
			num_mail = SnailMail::Mail.count
			mail = SnailMail::Mail.get_mail
			mail.length.must_equal num_mail
		end

		it 'must filter the records by from when it is passed in as a parameter' do
			num_mail = SnailMail::Mail.where({from: "ewaters"}).count
			params = Hash.new
			params[:from] = "ewaters"
			mail = SnailMail::Mail.get_mail params
			mail.length.must_equal num_mail
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_mail = SnailMail::Mail.where({from: "ewaters", to: "nwaters"}).count
			params = Hash.new
			params[:from] = "ewaters"
			params[:to] = "nwaters"
			mail = SnailMail::Mail.get_mail params
			mail.length.must_equal num_mail
		end

	end

end
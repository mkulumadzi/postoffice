require_relative '../../spec_helper'

describe SnailMail::Mail do

	Mongoid.load!('config/mongoid.yml')

	before do
		# SnailMail::Person.create(
		# 	name: "Evan"
		# )
		# SnailMail::Person.ceate(
		# 	name: "Neal"
		# )
	end

	describe 'create mail' do

		before do
			@num_records = SnailMail::Mail.count
			SnailMail::Mail.create!(
				from: "Evan",
				to: "Neal",
				content: "What up",
				status: "SENT"
			)
		end

		it 'must create a new piece of mail' do
			SnailMail::Mail.count.must_equal @num_records + 1
		end

		it 'must store the person it is from' do
			SnailMail::Mail.where(from: "Evan").exists?.must_equal true
		end

		it 'must store person it is to' do
			SnailMail::Mail.where(to: "Neal").exists?.must_equal true
		end

		it 'must store the content' do
			SnailMail::Mail.where(content: "What up").exists?.must_equal true
		end

		it 'must store the status as SENT' do
			SnailMail::Mail.where(status: "SENT").exists?.must_equal true
		end

	end

end
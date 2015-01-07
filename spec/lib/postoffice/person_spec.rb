require_relative '../../spec_helper'

describe SnailMail::Person do

	Mongoid.load!('config/mongoid.yml')

	# # Remove records from the person collection
	# before do
	# 	SnailMail::Person.delete_all
	# end

	describe 'create a person' do

		before do
			@num_records = SnailMail::Person.count
			SnailMail::Person.create!(
				name: "Evan",
				username: "ewaters",
				address1: "121 W 3rd St",
				city: "New York",
				state: "NY",
				zip: "10012"
			)
		end

		it 'must create a new person record' do
			SnailMail::Person.count.must_equal @num_records + 1
		end

		# To Do: Test this, better
		it 'must store the name' do
			SnailMail::Person.where(name: "Evan").exists?.must_equal true
		end

		it 'must store the username' do
			SnailMail::Person.where(username: "ewaters").exists?.must_equal true
		end

		it 'must store the address' do
			SnailMail::Person.where(address1: "121 W 3rd St").exists?.must_equal true
		end

		it 'must store the state' do
			SnailMail::Person.where(state: "NY").exists?.must_equal true
		end

		it 'must store the zip code' do
			SnailMail::Person.where(zip: "10012").exists?.must_equal true
		end

	end

end
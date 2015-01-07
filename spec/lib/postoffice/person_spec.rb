require_relative '../../spec_helper'

describe SnailMail::Person do

	Mongoid.load!('config/mongoid.yml')

	# # Remove records from the person collection
	# before do
	# 	SnailMail::Person.delete_all
	# end

	describe 'create a person' do

		before do
			@person = SnailMail::Person.create!(
				name: "Evan",
				username: "ewaters",
				address1: "121 W 3rd St",
				city: "New York",
				state: "NY",
				zip: "10012"
			)
		end

		it 'must create a new person record' do
			@person.must_be_instance_of SnailMail::Person
		end

		it 'must store the name' do
			@person.name.must_equal 'Evan'
		end

		it 'must store the username' do
			@person.username.must_equal 'ewaters'
		end

		it 'must store the address' do
			@person.address1.must_equal '121 W 3rd St'
		end

		it 'must store the state' do
			@person.state.must_equal 'NY'
		end

		it 'must store the zip code' do
			@person.zip.must_equal '10012'
		end

	end

end
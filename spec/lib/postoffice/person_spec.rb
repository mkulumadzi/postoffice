require_relative '../../spec_helper'

describe SnailMail::Person do

	Mongoid.load!('config/mongoid.yml')

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

		describe 'store the fields' do

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

		describe 'ensure username is unique' do

			before do
				SnailMail::Person.create!(
					name: "Neal",
					username: "nwaters",
					address1: "44 Prichard Street",
					city: "Somerville",
					state: "MA",
					zip: "02134"
				)
			end

			it 'must thrown an error if a record is submitted with a duplicate username' do
				assert_raises (
					SnailMail::Person.create!(
						name: "Neal",
						username: "nwaters",
						address1: "44 Prichard Street",
						city: "Somerville",
						state: "MA",
						zip: "02134"
					)
				).must_equal 'foo'
			end

		end

	end

	describe 'get people' do

		it 'must get all of the people if no parameters are given' do
			num_people = SnailMail::Person.count
			people = SnailMail::Person.get_people
			people.length.must_equal num_people
		end

		it 'must filter the records by username when it is passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "ewaters"}).count
			params = Hash.new
			params[:username] = "ewaters"
			people = SnailMail::Person.get_people params
			people.length.must_equal num_people
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "ewaters", name: "Evan"}).count
			params = Hash.new
			params[:username] = "ewaters"
			params[:name] = "Evan"
			people = SnailMail::Person.get_people params
			people.length.must_equal num_people
		end

	end

	# describe 'find people by criteria' do

	# 	before do
	# 		@people = SnailMail::Person.get_it "kasabian"
	# 	end

	# 	## Commenting out this test for now while I fix the getting and rendering.
	# 	# it 'must return people with the correct username' do
	# 	# 	@people.must_include "kasabian"
	# 	# end

	# end

end
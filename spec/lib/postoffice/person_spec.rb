require_relative '../../spec_helper'

describe SnailMail::Person do

	Mongoid.load!('config/mongoid.yml')

	describe 'create a person' do

		before do

			@person1_username = SnailMail::Person.random_username
			@person1 = SnailMail::Person.create!(
				name: "Evan",
				username: "#{@person1_username}",
				address1: "121 W 3rd St",
				city: "New York",
				state: "NY",
				zip: "10012"
			)

		end

		it 'should create a random username' do
			assert_match(/[[:upper:]]{8}/, @person1_username)
		end

		describe 'store the fields' do

			it 'must create a new person record' do
				@person1.must_be_instance_of SnailMail::Person
			end

			it 'must store the name' do
				@person1.name.must_equal 'Evan'
			end

			it 'must store the username' do
				@person1.username.must_equal "#{@person1_username}"
			end

			it 'must store the address' do
				@person1.address1.must_equal '121 W 3rd St'
			end

			it 'must store the city' do
				@person1.city.must_equal 'New York'
			end

			it 'must store the state' do
				@person1.state.must_equal 'NY'
			end

			it 'must store the zip code' do
				@person1.zip.must_equal '10012'
			end

		end

		describe 'ensure username is unique' do

			before do
				@person1_username = SnailMail::Person.random_username
				@person1 = SnailMail::Person.create!(
					name: "Evan",
					username: "#{@person1_username}",
					address1: "121 W 3rd St",
					city: "New York",
					state: "NY",
					zip: "10012"
				)
			end

			it 'must thrown an error if a record is submitted with a duplicate username' do
				assert_raises(Moped::Errors::OperationFailure) {
					SnailMail::Person.create!(
						name: "Evan",
						username: "#{@person1_username}",
						address1: "44 Prichard Street"
					)
				}
			end

		end

	end

	describe 'get people' do

		before do
			@person1_username = SnailMail::Person.random_username
			@person1 = SnailMail::Person.create!(
				name: "Evan",
				username: "#{@person1_username}",
				address1: "121 W 3rd St",
				city: "New York",
				state: "NY",
				zip: "10012"
			)
		end

		it 'must get all of the people if no parameters are given' do
			people = SnailMail::Person.get_people
			people.length.must_equal SnailMail::Person.count
		end

		it 'must filter the records by username when it is passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "#{@person1_username}"}).count
			params = Hash.new
			params[:username] = "#{@person1_username}"
			people = SnailMail::Person.get_people params
			people.length.must_equal num_people
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "#{@person1_username}", name: "Evan"}).count
			params = Hash.new
			params[:username] = "#{@person1_username}"
			params[:name] = "Evan"
			people = SnailMail::Person.get_people params
			people.length.must_equal num_people
		end

	end

end
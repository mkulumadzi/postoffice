
require_relative '../../spec_helper'

describe SnailMail::PersonService do

	Mongoid.load!('config/mongoid.yml')

	let ( :person1 ) {
		data =  JSON.parse '{"name": "Evan", "username": "' + SnailMail::Person.random_username + '", "email": "evan@test.com", "phone": "(555) 444-1324", "address1": "121 W 3rd St", "city": "New York", "state": "NY", "zip": "10012", "password": "password"}'	

		SnailMail::PersonService.create_person data
	}


	describe 'create person' do

		it 'must create a new person record' do
			person1.must_be_instance_of SnailMail::Person
		end

		it 'must store the name' do
			person1.name.must_equal 'Evan'
		end

		it 'must store the email' do
			person1.email.must_equal 'evan@test.com'
		end

		describe 'store the phone number' do

			it 'must remove spaces from the phone number' do
				phone = SnailMail::PersonService.format_phone_number '555 444 3333'
				phone.must_equal '5554443333'
			end

			it 'must remove special characters from the phone number' do
				phone = SnailMail::PersonService.format_phone_number '(555)444-3333'
				phone.must_equal '5554443333'
			end

			it 'must remove letters from the phone number' do
				phone = SnailMail::PersonService.format_phone_number 'aB5554443333'
				phone.must_equal '5554443333'
			end

			it 'msut store the phone number as a string of numeric digits' do
				person1.phone.must_equal '5554441324'
			end

		end

		it 'should create a random username' do
			assert_match(/[[:upper:]]{8}/, person1.username)
		end

		it 'must store the address' do
			person1.address1.must_equal '121 W 3rd St'
		end

		it 'must store the city' do
			person1.city.must_equal 'New York'
		end

		it 'must store the state' do
			person1.state.must_equal 'NY'
		end

		it 'must store the zip code' do
			person1.zip.must_equal '10012'
		end

		it 'must store the salt as a String' do
			person1.salt.must_be_instance_of String
		end

		it 'must store the hashed password as a String' do
			person1.hashed_password.must_be_instance_of String
		end

	end



	describe 'register person as user with salt and hashed password' do

		describe 'create a random salt string' do

			it 'must generate a hex string' do
				SnailMail::PersonService.salt.must_be_instance_of String
			end

			it 'must generate a hex string that is 128 characters long' do
				SnailMail::PersonService.salt.length.must_equal 128
			end

		end

		describe 'create a hash with the password and salt' do

			it 'must have a method that appends two strings together' do
				SnailMail::PersonService.append_salt("password", "salt").must_equal "passwordsalt"
			end

			it 'must have a method that creates a secure hash from a string' do
				SnailMail::PersonService.hash_string("passwordsalt").must_equal Digest::SHA256.bubblebabble("passwordsalt")
			end

			it 'must create a secure hash from a password and a randomly generated salt string' do
				password = "password"
				salt = SnailMail::PersonService.salt
				hashed_password = Digest::SHA256.bubblebabble(password + salt)
				SnailMail::PersonService.hash_password(password, salt).must_equal hashed_password
			end

		end

		describe 'create a person with salt and a hashed password' do

			before do
				username = SnailMail::Person.random_username
				data = JSON.parse '{"username": "' + username + '", "name":"Kasabian", "password": "password"}'
				@person = SnailMail::PersonService.create_person data
			end

			it 'must create a person' do
				@person.must_be_instance_of SnailMail::Person
			end

			it 'must have a string stored as the salt for the person' do
				@person.salt.must_be_instance_of String
			end

			it 'must have a string stored as the hashed password for the person' do
				@person.hashed_password.must_be_instance_of String
			end

		end

		describe 'check a login' do

			it 'must find the person record' do
				person_found = SnailMail::PersonService.get_person_for_username person1.username
				person_found.must_be_instance_of SnailMail::Person
			end

			it 'must return true if the correct password is submitted' do
				data = JSON.parse '{"username": "' + person1.username + '", "password": "password"}'
				result = SnailMail::PersonService.check_login data
				result.must_equal true
			end

			it 'must return false if an incorrect password is submitted' do
				data = JSON.parse '{"username": "' + person1.username + '", "password": "wrong_password"}'
				result = SnailMail::PersonService.check_login data
				result.must_equal false
			end

		end

	end

	describe 'get people' do

		it 'must get all of the people if no parameters are given' do
			people = SnailMail::PersonService.get_people
			people.length.must_equal SnailMail::Person.count
		end

		it 'must filter the records by username when it is passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "#{person1.username}"}).count
			params = Hash.new
			params[:username] = "#{person1.username}"
			people = SnailMail::PersonService.get_people params
			people.length.must_equal num_people
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "#{person1.username}", name: "Evan"}).count
			params = Hash.new
			params[:username] = "#{person1.username}"
			params[:name] = "Evan"
			people = SnailMail::PersonService.get_people params
			people.length.must_equal num_people
		end

	end

end
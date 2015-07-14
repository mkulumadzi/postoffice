
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

			describe 'get the person record' do

				it 'must get the person record if the username is submitted' do
					person = SnailMail::PersonService.find_person_record_from_login person1.username
					person.must_be_instance_of SnailMail::Person
				end

				it 'must get the person record if an email is submitted' do
					person = SnailMail::PersonService.find_person_record_from_login person1.email
					person.must_be_instance_of SnailMail::Person
				end

				it 'must return nil if a person record is not found' do
					person = SnailMail::PersonService.find_person_record_from_login "wrong_username"
					person.must_equal nil
				end

			end

			it 'must return a person if the correct password is submitted' do
				data = JSON.parse '{"username": "' + person1.username + '", "password": "password"}'
				result = SnailMail::PersonService.check_login data
				result.must_be_instance_of SnailMail::Person
			end

			it 'must return nil if an incorrect password is submitted' do
				data = JSON.parse '{"username": "' + person1.username + '", "password": "wrong_password"}'
				result = SnailMail::PersonService.check_login data
				result.must_equal nil
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

	describe 'search people' do

		before do

			@person1 = SnailMail::Person.create!(
				name: "Evan Waters",
				username: "bigedubs" + SnailMail::Person.random_username,
				email: "evanw@test.com"
			)

			@person2 = SnailMail::Person.create!(
				name: "Evan Rachel Wood",
				username: "erach" + SnailMail::Person.random_username,
				email: "evanrw@test.com"
			)

			@person3 = SnailMail::Person.create!(
				name: "Evan Spiegel",
				username: "espiegs" + SnailMail::Person.random_username,
				email: "espiegs2013@test.com"
			)

			@rando_name = SnailMail::Person.random_username

			@person4 = SnailMail::Person.create!(
				name: "Neal #{@rando_name}",
				username: "Woodsman" + SnailMail::Person.random_username,
				email: "nwat4@test.com"
			)

			@person5 = SnailMail::Person.create!(
				name: "Neal Waters",
				username: @rando_name + SnailMail::Person.random_username,
				email: "nwat4@test.com"
			)



			parameters = Hash.new()
			parameters["term"] = "Evan"
			parameters["limit"] = 2
			
			@people_returned = SnailMail::PersonService.search_people parameters

		end

		it 'must return an array of people' do
			@people_returned[0].must_be_instance_of SnailMail::Person
		end

		it 'must return only people whose name or username matches the search string' do
			num_not_match = 0
			@people_returned.each do |person|
				if person.name.match(/Evan/) == nil && person.username.match(/Evan/) == nil
					num_not_match += 1
				end
			end

			num_not_match.must_equal 0
		end

		it 'must limit the number of records returned by the "limit" parameter' do
			assert_operator @people_returned.count, :<=, 2
		end

		describe 'some additional search cases' do

			it 'limit the number of records returned to 25 by default, if no limit parameter is given' do
				parameters = Hash.new()
				parameters["term"] = "Evan"
				people_returned = SnailMail::PersonService.search_people parameters

				assert_operator people_returned.count, :<=, 25

			end

			describe 'search term is valid for a username record and a name record' do

				before do
					parameters = Hash.new()
					parameters["term"] = @rando_name
					@people_returned = SnailMail::PersonService.search_people parameters
				end

				it 'must return matches for the username' do
					@people_returned.must_include @person4
				end

				it 'must return matches for the name' do
					@people_returned.must_include @person5
				end

			end

		end

	end

end
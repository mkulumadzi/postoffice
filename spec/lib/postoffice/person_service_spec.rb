
require_relative '../../spec_helper'

describe SnailMail::PersonService do

	Mongoid.load!('config/mongoid.yml')

	before do
		@person1 = build(:person, name: "Evan Waters", username: "bigedubs", email: "evan@test.com", phone: "5554443321")
	end

	# let ( :person1 ) {
	# 	data =  JSON.parse '{"name": "Evan", "username": "' + SnailMail::Person.random_username + '", "email": "evan@test.com", "phone": "(555) 444-1324", "address1": "121 W 3rd St", "city": "New York", "state": "NY", "zip": "10012", "password": "password"}'	

	# 	SnailMail::PersonService.create_person data
	# }


	describe 'create person' do

		before do
			@username = SnailMail::Person.random_username
			data = Hash["name", "Evan", "username", @username, "email", "evan@test.com", "phone", "(555) 444-1324", "address1", "121 W 3rd St", "city", "New York", "state", "NY", "zip", "10012", "password", "password"]
			@person = SnailMail::PersonService.create_person data
		end

		it 'must create a new person record' do
			@person.must_be_instance_of SnailMail::Person
		end

		it 'must store the username' do
			@person.username.must_equal @username
		end

		it 'must store the name' do
			@person.name.must_equal 'Evan'
		end

		describe 'validate required fields' do
			
			it 'must throw an exception if email is missing' do
				data = Hash["phone", "685714571"]
				assert_raises RuntimeError do
					SnailMail::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception if email is duplicate' do
				data = Hash["email", @person.email, "phone", "685714571"]
				assert_raises RuntimeError do
					SnailMail::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception if phone is missing' do
				data = Hash["email", "wha@test.co"]
				assert_raises RuntimeError do
					SnailMail::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception if email is duplicate' do
				data = Hash["email", "wha@test.co", "phone", @person.phone]
				assert_raises RuntimeError do
					SnailMail::PersonService.validate_required_fields data
				end
			end

			it 'must call this function when creating a person' do
				username = SnailMail::Person.random_username
				phone = rand(1000000)
				data = Hash["username", username, "email", "#{@person.email}", "phone", phone.to_s]

				# To Do: Figure out how to use mocked methods here
				# mocked_method = MiniTest::Mock.new
				# mocked_method.expect :validate_required_fields, nil, [data]

				# SnailMail::PersonService.create_person data

				# mocked_method.verify

				assert_raises RuntimeError do
					SnailMail::PersonService.create_person data
				end
			end

		end

		it 'must store the email' do
			@person.email.must_equal 'evan@test.com'
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
				@person.phone.must_equal '5554441324'
			end

		end

		it 'must store the address' do
			@person.address1.must_equal '121 W 3rd St'
		end

		it 'must store the city' do
			@person.city.must_equal 'New York'
		end

		it 'must store the state' do
			@person.state.must_equal 'NY'
		end

		it 'must store the zip code' do
			@person.zip.must_equal '10012'
		end

		it 'must store the salt as a String' do
			@person.salt.must_be_instance_of String
		end

		it 'must store the hashed password as a String' do
			@person.hashed_password.must_be_instance_of String
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

		describe 'create a person with salt and a hashed password and check log in' do

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

			describe 'get the person record' do

				it 'must get the person record if the username is submitted' do
					person = SnailMail::PersonService.find_person_record_from_login @person.username
					person.must_be_instance_of SnailMail::Person
				end

				it 'must get the person record if an email is submitted' do
					person = SnailMail::PersonService.find_person_record_from_login @person.email
					person.must_be_instance_of SnailMail::Person
				end

				it 'must return nil if a person record is not found' do
					person = SnailMail::PersonService.find_person_record_from_login "wrong_username"
					person.must_equal nil
				end

			end

			it 'must return a person if the correct password is submitted' do
				data = JSON.parse '{"username": "' + @person.username + '", "password": "password"}'
				result = SnailMail::PersonService.check_login data
				result.must_be_instance_of SnailMail::Person
			end

			it 'must return nil if an incorrect password is submitted' do
				data = JSON.parse '{"username": "' + @person.username + '", "password": "wrong_password"}'
				result = SnailMail::PersonService.check_login data
				result.must_equal nil
			end

		end

	end

	describe 'get people' do

		before do
			@person2 = build(:person, name: "Joe Person", username: SnailMail::Person.random_username, email: "evan@test.com", phone: "5554443321")
		end

		it 'must get all of the people if no parameters are given' do
			people = SnailMail::PersonService.get_people
			people.length.must_equal SnailMail::Person.count
		end

		it 'must filter the records by username when it is passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "#{@person2.username}"}).count
			params = Hash["username", @person2.username]
			people = SnailMail::PersonService.get_people params
			people.length.must_equal num_people
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_people = SnailMail::Person.where({username: "#{@person2.username}", name: "Joe Person"}).count
			params = Hash["username", @person2.username, "name", "Joe Person"]
			people = SnailMail::PersonService.get_people params
			people.length.must_equal num_people
		end

	end

	describe 'search' do

		before do

			@person2 = create(:person, name: "Evan Rachel Wood", username: "erach#{SnailMail::Person.random_username}", email: "evanrw@test.com")

			@person3 = create(:person, name: "Evan Spiegel", username: "espiegs#{SnailMail::Person.random_username}", email: "espiegs2013@test.com")

			@rando_name = SnailMail::Person.random_username

			@person4 = create(:person, name: "Neal #{@rando_name}", username: "Woodsman#{SnailMail::Person.random_username}", email: "nwat4@test.com", phone: "5554446621")

			@person5 = create(:person, name: "Neal Waters", username: @rando_name + SnailMail::Person.random_username, email: "nwat4@test.com", phone: "5555553321")

		end

		describe 'simple search' do

			before do
				parameters = Hash["term", "Evan", "limit", 2]
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

		describe 'bulk search of people' do

			describe 'get people from email array' do

				before do
					@email_array = [@person1.email, @person2.email, "not_in_the_database@test.com"]
					@people = SnailMail::PersonService.get_people_from_email_array @email_array
				end

				it 'must return an array of people do' do
					@people[0].must_be_instance_of SnailMail::Person
				end

				it 'must return person records who match the search terms' do 
					@people[0].email.must_equal @person1.email || @person2.email
					
				end

				it 'must return a person record for each successful search result' do
					num_expected = SnailMail::Person.or({email: @person1.email}, {email: @person2.email}).count
					@people.count.must_equal num_expected
				end

			end

			describe 'get people from phone array' do

				before do
					@phone_array = ["5554446621", "5555553321", "1234"]
					@people = SnailMail::PersonService.get_people_from_phone_array @phone_array
				end

				it 'must return an array of people do' do
					@people[0].must_be_instance_of SnailMail::Person
				end

				it 'must return person records who match the search terms' do 
					@people[0].phone.must_equal "5554446621" || "5555553321"
				end

				it 'must return a person record for each successful search result' do
					num_expected = SnailMail::Person.or({phone: "5554446621"}, {phone: "5555553321"}).count
					@people.count.must_equal num_expected
				end

				it 'must remove special characters when searching phone strings' do
					people = SnailMail::PersonService.get_people_from_phone_array ["(555) 555-3321"]
					people[0].phone.must_equal "5555553321"
				end

			end

			# Might need to break this down into multiple tests...
			it 'must return a unique array of all people with matching email and phone records' do
				data = []

				entry1 = Hash.new
				entry1["emails"] = ["evanw@test.com"]
				entry1["phoneNumbers"] = ["5554443321"]

				entry2 = Hash.new
				entry2["emails"] = ["espiegs2013@test.com"]
				entry2["phoneNumbers"] = []

				data.append(entry1)
				data.append(entry2)
				
				people = SnailMail::PersonService.bulk_search data

				expected_people = []
				SnailMail::Person.or({email: "evanw@test.com"}, {email: "espiegs2013@test.com"}, {phone: "5554443321"}).each do |person|
					expected_people << person
				end

				people.sort.must_equal expected_people.uniq.sort
			end

		end

	end

end
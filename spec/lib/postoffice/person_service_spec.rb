require_relative '../../spec_helper'

describe Postoffice::PersonService do

	describe 'create person' do

		before do
			#Setting up random values, since these need to be unique
			@username = random_username
			@phone = rand(1000000000).to_s
			@email = SecureRandom.uuid()

			data = Hash["name", "Evan", "username", @username, "email", @email, "phone", @phone, "address1", "121 W 3rd St", "city", "New York", "state", "NY", "zip", "10012", "password", "password"]
			@person = Postoffice::PersonService.create_person data
		end

		it 'must create a new person record' do
			@person.must_be_instance_of Postoffice::Person
		end

		it 'must store the username' do
			@person.username.must_equal @username
		end

		it 'must store the name' do
			@person.name.must_equal 'Evan'
		end

		describe 'validate required fields' do

			it 'must throw an exception if username is missing' do
				data = Hash["email", "testemail", "phone", "685714571", "password", "password"]
				assert_raises RuntimeError do
					Postoffice::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception is username is empty' do
				data = Hash["username", "", "email", "testemail", "phone", "685714571", "password", "password"]
				assert_raises RuntimeError do
					Postoffice::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception if email is missing' do
				data = Hash["username", "test", "phone", "685714571", "password", "password"]
				assert_raises RuntimeError do
					Postoffice::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception is email is empty' do
				data = Hash["username", "test", "email", "", "phone", "685714571", "password", "password"]
				assert_raises RuntimeError do
					Postoffice::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception if email is duplicate' do
				data = Hash["username", "test", "email", @person.email, "phone", "685714571", "password", "password"]
				assert_raises RuntimeError do
					Postoffice::PersonService.validate_required_fields data
				end
			end

			it 'must throw an exception if phone is duplicate' do
				data = Hash["username", "test", "email", "wha@test.co", "phone", @person.phone, "password", "password"]
				assert_raises RuntimeError do
					Postoffice::PersonService.validate_required_fields data
				end
			end

			it 'must not throw an exception if phone is empty' do
				data = Hash["username", "test", "email", "wha@test.co", "phone", "", "password", "password"]
				Postoffice::PersonService.validate_required_fields(data).must_equal nil
			end

			it 'must throw an exception is password is empty' do
				data = Hash["username", "test", "email", "test", "phone", "5556665555", "password", ""]
				assert_raises RuntimeError do
					Postoffice::PersonService.validate_required_fields data
				end
			end

			it 'must call this function when creating a person' do
				username = random_username
				phone = rand(1000000)
				data = Hash["username", username, "email", "#{@person.email}", "phone", phone.to_s, "password", "password"]

				# To Do: Figure out how to use mocked methods here
				# mocked_method = MiniTest::Mock.new
				# mocked_method.expect :validate_required_fields, nil, [data]

				# Postoffice::PersonService.create_person data

				# mocked_method.verify

				assert_raises RuntimeError do
					Postoffice::PersonService.create_person data
				end
			end

		end

		it 'must store the email' do
			@person.email.must_equal @email
		end

		describe 'store the phone number' do

			it 'must remove spaces from the phone number' do
				phone = Postoffice::PersonService.format_phone_number '555 444 3333'
				phone.must_equal '5554443333'
			end

			it 'must remove special characters from the phone number' do
				phone = Postoffice::PersonService.format_phone_number '(555)444-3333'
				phone.must_equal '5554443333'
			end

			it 'must remove letters from the phone number' do
				phone = Postoffice::PersonService.format_phone_number 'aB5554443333'
				phone.must_equal '5554443333'
			end

			it 'must store the phone number as a string of numeric digits' do
				@person.phone.must_equal Postoffice::PersonService.format_phone_number @phone
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

	describe 'get people' do

		before do
			@person = build(:person, name: "Joe Person", username: random_username)
		end

		it 'must get all of the people if no parameters are given' do
			people = Postoffice::PersonService.get_people
			people.length.must_equal Postoffice::Person.count
		end

		it 'must filter the records by username when it is passed in as a parameter' do
			num_people = Postoffice::Person.where({username: "#{@person.username}"}).count
			params = Hash["username", @person.username]
			people = Postoffice::PersonService.get_people params
			people.length.must_equal num_people
		end

		it 'must filter the records by username and name when both are passed in as a parameter' do
			num_people = Postoffice::Person.where({username: "#{@person.username}", name: "Joe Person"}).count
			params = Hash["username", @person.username, "name", "Joe Person"]
			people = Postoffice::PersonService.get_people params
			people.length.must_equal num_people
		end

	end

	describe 'search' do

		before do

			@person1 = create(:person, username: random_username, phone: random_phone, email: random_email)

			@person2 = create(:person, name: "Evan Rachel Wood", username: "erach#{random_username}", phone: random_phone, email: random_email)

			@person3 = create(:person, name: "Evan Spiegel", username: "espiegs#{random_username}", phone: random_phone, email: random_email)

			@rando_name = random_username

			@person4 = create(:person, name: "Neal #{@rando_name}", username: "Woodsman#{random_username}", phone: random_phone, email: random_email)

			@person5 = create(:person, name: "Neal Waters", username: @rando_name + random_username, phone: random_phone, email: random_email)

		end

		describe 'simple search' do

			before do
				parameters = Hash["term", "Evan", "limit", 2]
				@people_returned = Postoffice::PersonService.search_people parameters
			end

			it 'must return an array of people' do
				@people_returned[0].must_be_instance_of Postoffice::Person
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

				it 'must limit the number of records returned to 25 by default, if no limit parameter is given' do
					parameters = Hash["term", "Evan"]
					people_returned = Postoffice::PersonService.search_people parameters

					assert_operator people_returned.count, :<=, 25

				end

				it 'must replace instances of + with a space' do
					Postoffice::PersonService.format_search_term("A+term").must_equal "A term"
				end

				it 'must format the search string and return correct results' do
					parameters = Hash["term", "Evan+Rachel"]
					people_returned = Postoffice::PersonService.search_people parameters

					assert_operator people_returned.count, :>=, 1
				end

				describe 'search term is valid for a username record and a name record' do

					before do
						@parameters = Hash["term", @rando_name]
						@people_returned = Postoffice::PersonService.search_people @parameters
					end

					it 'must return matches for the name' do
						@people_returned.must_include @person4
					end

					it 'must return matches for the username' do
						@people_returned.must_include @person5
					end

				end

			end

		end

	end

	describe 'find people from list of emails' do

		before do
			@personA = create(:person, username: random_username, email: "person1@google.com")
			@personB = create(:person, username: random_username, email: "person2@google.com")
			@personC = create(:person, username: random_username, email: "person3@google.com")
			@personD = create(:person, username: random_username, email: "person4@google.com")

			@email_array = ["person1@google.com", "person2@google.com", "person@yahoo.com", "person@hotmail.com", "person4@google.com"]

			@people = Postoffice::PersonService.find_people_from_list_of_emails @email_array
		end

		it 'must return an array of people' do
			@people[0].must_be_instance_of Postoffice::Person
		end

		it 'must return all people who have a matching email' do
			@people.count.must_equal 3
		end

	end

	describe 'check field availability' do

		describe 'look for a field that can be checked (username, email, phone)' do

			describe 'search for a username that is available' do

					before do
						params = Hash["username", "availableusername"]
						@result = Postoffice::PersonService.check_field_availability params
					end

					it 'must return a hash indicating that the field is avilable' do
						@result.must_equal Hash["username", "available"]
					end

			end

			it 'must check phone numbers' do
				params = Hash["phone", "availablephone"]
				result = Postoffice::PersonService.check_field_availability params
				result.must_equal Hash["phone", "available"]
			end

			it 'must check phone emails' do
				params = Hash["email", "availableemail"]
				result = Postoffice::PersonService.check_field_availability params
				result.must_equal Hash["email", "available"]
			end

			it 'if a field is already used, it must indicate that it is unavailble' do
				person = create(:person, username: random_username)
				params = Hash["username", person.username]
				result = Postoffice::PersonService.check_field_availability(params)
				result.must_equal Hash["username", "unavailable"]
			end

		end

		describe 'invalid parameters' do

			it 'must raise a RuntimeError if more than one field is submitted' do
				params = Hash["username", "user", "phone", "555"]
				assert_raises RuntimeError do
					Postoffice::PersonService.check_field_availability params
				end
			end

			it 'must raise an RuntimeError if the parameters include a field that cannot be checked' do
				params = Hash["name", "A Name"]
				assert_raises RuntimeError do
					Postoffice::PersonService.check_field_availability params
				end
			end

		end

	end

end

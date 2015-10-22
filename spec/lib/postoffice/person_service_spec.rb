require_relative '../../spec_helper'

describe Postoffice::PersonService do

	describe 'create person' do

		before do
			#Setting up random values, since these need to be unique
			@username = random_username
			@phone = rand(1000000000).to_s
			@email = SecureRandom.uuid()

			data = Hash["given_name", "Evan", "family_name", "Waters", "username", @username, "email", @email, "phone", @phone, "address1", "121 W 3rd St", "city", "New York", "state", "NY", "zip", "10012", "password", "password"]
			@person = Postoffice::PersonService.create_person data
		end

		it 'must create a new person record' do
			@person.must_be_instance_of Postoffice::Person
		end

		it 'must store the username' do
			@person.username.must_equal @username
		end

		it 'must store the given name' do
			@person.given_name.must_equal 'Evan'
		end

		it 'must store the family name' do
			@person.family_name.must_equal 'Waters'
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

			it 'must not thrown an exception if no phone is submitted' do
				data = Hash["username", "test", "email", "wha@test.co", "password", "password"]
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

		it 'must indicate that the email address has not been validated' do
			@person.email_address_validated.must_equal false
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

	describe 'update person' do

		before do
			@person = create(:person, username: random_username)
		end

		describe 'successful update' do

			before do
				data = Hash("given_name" => "New", "family_name" => "Name", "email" => "#{random_username}@test.com")
				@result = Postoffice::PersonService.update_person @person.id, data
				@updated_record = Postoffice::Person.find(@person.id)
			end

			it 'must have updated the attributes that were provided' do
				@updated_record.given_name.must_equal "New"
			end

			it 'must not update any fields that were not included in the data' do
				@updated_record.phone.must_equal @person.phone
			end

			it 'must have sent an email to validate a new email address' do
				@result[:message].must_equal "Test job accepted"
			end

		end

		describe 'error conditions' do

			it 'must raise an ArgumentError if the username is attempted to be updated' do
				data = Hash("username" => "newusername")
				assert_raises ArgumentError do
					Postoffice::PersonService.update_person @person.id, data
				end
			end

			it 'must raise a RuntimeError if the data includes an emial address that already exists' do
				another_person = create(:person, username: random_username, email: "#{random_username}@test.com")
				data = Hash("email" => another_person.email)
				assert_raises RuntimeError do
					Postoffice::PersonService.update_person @person.id, data
				end
			end

			it 'must not raise a RuntimeError if the email address equals the persons email address' do
				data = Hash("email" => @person.email)
				Postoffice::PersonService.update_person @person.id, data
			end

		end

		describe 'send email to validate email address change' do

			before do
				@personA = create(:person, username: random_username, email: "#{random_username}@test.com")
			end

			describe 'send email' do

				before do
					@new_email = "#{random_username}@test.com"
					@old_email = @personA.email
					@personA.email = @new_email
					@personA.save
					data = Hash("email" => @new_email)
					@result = Postoffice::PersonService.send_email_to_validate_email_address_change @personA, data, @old_email
				end

				it 'must send an email asking for the new email address to be validated if the email address is changed' do
					@result[:message].must_equal "Test job accepted"
				end

				it 'must have sent the email to the new email address' do
					@result[:to].must_equal @new_email
				end

			end

			it 'must not send an email if the email address has not changed' do
				data = Hash("email" => @personA.email)
				result = Postoffice::PersonService.send_email_to_validate_email_address_change @personA, data, @personA.email
				result.must_equal nil
			end

			it 'must not send an email if an email address is not included in the data' do
				data = Hash("given_name" => "Harold")
				result = Postoffice::PersonService.send_email_to_validate_email_address_change @personA, data, @personA.email
				result.must_equal nil
			end

		end

	end

	describe 'get people' do

		before do
			@person = build(:person, given_name: "Joe", family_name: "Person", username: random_username)
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

		it 'must filter the records by username and given name when both are passed in as a parameter' do
			num_people = Postoffice::Person.where({username: "#{@person.username}", given_name: "Joe", family_name: "Person"}).count
			params = Hash["username", @person.username, "given_name", "Joe"]
			people = Postoffice::PersonService.get_people params
			people.length.must_equal num_people
		end

	end

	describe 'search' do

		describe 'simple search' do

			describe 'create query for search term' do

				it 'must return a Mongoid Selector' do
					query = Postoffice::PersonService.create_query_for_search_term "Evan"
					query.must_be_instance_of Mongoid::Criteria
				end

				it 'must search a single term for matches against given name, family name and username' do
					query = Postoffice::PersonService.create_query_for_search_term "Evan"
					query.selector.must_equal Hash("$or"=>[{"given_name"=>/Evan/}, {"family_name"=>/Evan/}, {"username"=>/Evan/}])
				end

				it 'must search two terms separated by a + against the given and family name, or the family and given name' do
					query = Postoffice::PersonService.create_query_for_search_term "Evan+Waters"
					query.selector.must_equal Hash("$or"=>[{"given_name"=>/Evan/, "family_name"=>/Waters/}, {"given_name"=>/Waters/, "family_name"=>/Evan/}])
				end

				describe 'perform a search' do

					it 'must return an array of people' do
						params = Hash("term" => "Eva")
						people = Postoffice::PersonService.search_people params
						people[0].must_be_instance_of Postoffice::Person
					end

					it 'must return partial matches of a single term with given name' do
						person = create(:person, username: random_username, given_name: random_username)
						term = person.given_name[0..2]
						params = Hash("term" => "#{term}")
						people = Postoffice::PersonService.search_people params
						people.must_include person
					end

					it 'must return partial matches of a single term with family name' do
						person = create(:person, username: random_username, family_name: random_username)
						term = person.family_name[0..2]
						params = Hash("term" => "#{term}")
						people = Postoffice::PersonService.search_people params
						people.must_include person
					end

					it 'must return partial matches of a single term with username' do
						person = create(:person, username: random_username)
						term = person.username[0..2]
						params = Hash("term" => "#{term}")
						people = Postoffice::PersonService.search_people params
						people.must_include person
					end

					it 'must find matches of multiple terms by if the first two match given_name and family_name' do
						person = create(:person, username: random_username, given_name: random_username, family_name: random_username)
						term1 = person.given_name[0..2]
						term2 = person.family_name[0..2]
						params = Hash("term" => "#{term1}+#{term2}")
						people = Postoffice::PersonService.search_people params
						people.must_include person
					end

					it 'must find matches of multiple terms by if the first two match family_name and given_name' do
						person = create(:person, username: random_username, given_name: random_username, family_name: random_username)
						term1 = person.given_name[0..2]
						term2 = person.family_name[0..2]
						params = Hash("term" => "#{term2}+#{term1}")
						people = Postoffice::PersonService.search_people params
						people.must_include person
					end

					it 'must limit the number of results returned by a limit parameter if it is presented' do
						person1 = create(:person, username: random_username, family_name: "Test")
						person2 = create(:person, username: random_username, family_name: "Test")
						params = Hash("term" => "Test", "limit" => 1)
						people = Postoffice::PersonService.search_people params
						people.count.must_equal 1
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

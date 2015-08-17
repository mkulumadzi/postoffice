require_relative '../../spec_helper'

describe Postoffice::LoginService do

	Mongoid.load!('config/mongoid.yml')

	describe 'create person' do

		before do
			#Setting up random values, since these need to be unique
			@username = random_username
			@phone = rand(1000000000).to_s
			@email = SecureRandom.uuid()

			data = Hash["name", "Evan", "username", @username, "email", @email, "phone", @phone, "address1", "121 W 3rd St", "city", "New York", "state", "NY", "zip", "10012", "password", "password"]
			@person = Postoffice::PersonService.create_person data
		end

		describe 'create a random salt string' do

			it 'must generate a hex string' do
				Postoffice::LoginService.salt.must_be_instance_of String
			end

			it 'must generate a hex string that is 128 characters long' do
				Postoffice::LoginService.salt.length.must_equal 128
			end

		end

		describe 'create a hash with the password and salt' do

			it 'must have a method that appends two strings together' do
				Postoffice::LoginService.append_salt("password", "salt").must_equal "passwordsalt"
			end

			it 'must have a method that creates a secure hash from a string' do
				Postoffice::LoginService.hash_string("passwordsalt").must_equal Digest::SHA256.bubblebabble("passwordsalt")
			end

			it 'must create a secure hash from a password and a randomly generated salt string' do
				password = "password"
				salt = Postoffice::LoginService.salt
				hashed_password = Digest::SHA256.bubblebabble(password + salt)
				Postoffice::LoginService.hash_password(password, salt).must_equal hashed_password
			end

		end

		describe 'login' do

			describe 'find record from login' do

				it 'must get the person record if the username is submitted' do
					person = Postoffice::LoginService.find_person_record_from_login @person.username
					person.must_be_instance_of Postoffice::Person
				end

				it 'must get the person record if an email is submitted' do
					person = Postoffice::LoginService.find_person_record_from_login @person.email
					person.must_be_instance_of Postoffice::Person
				end

				it 'must return nil if a person record is not found' do
					person = Postoffice::LoginService.find_person_record_from_login "wrong_username"
					person.must_equal nil
				end

			end

			describe 'check login' do

				it 'must return a person if the correct password is submitted' do
					data = JSON.parse '{"username": "' + @person.username + '", "password": "password"}'
					result = Postoffice::LoginService.check_login data
					result.must_be_instance_of Postoffice::Person
				end

				it 'must return nil if an incorrect password is submitted' do
					data = JSON.parse '{"username": "' + @person.username + '", "password": "wrong_password"}'
					result = Postoffice::LoginService.check_login data
					result.must_equal nil
				end

			end

			describe 'generate response body for route' do

				before do
					@response = JSON.parse(Postoffice::LoginService.response_for_successful_login @person)
				end

				it 'must include a token as a string in the response' do
					@response["access_token"].must_be_instance_of String
				end

				it 'must specify that the token type is bearer' do
					@response["token_type"].must_equal "bearer"
				end

				it 'must indicate that the token will expire in 3 months' do
					@response["expires_in"].to_i.must_equal 3600 * 24 * 72
				end

				it 'must include the person record as a document' do
					@response["person"]["username"].must_equal @person.username
				end

				it 'must not include sensitive fields like the users hashed password' do
					@response["person"]["hashed_password"].must_equal nil
				end

			end

		end

		describe 'reset password' do

			it 'must store the new hashed password and salt if the correct old password is submitted' do
				data = Hash["old_password", "password", "new_password", "password123"]
				Postoffice::LoginService.reset_password @person.id, data

				person = Postoffice::Person.find(@person.id)
				person.hashed_password.must_equal Postoffice::LoginService.hash_password "password123", person.salt
			end

			it 'must raise a Runtime Error if an incorrect password is submitted' do
				data = Hash["old_password", "wrongpassword", "new_password", "password123"]

				assert_raises RuntimeError do
					Postoffice::LoginService.reset_password @person.id, data
				end
			end

			it 'must raise a Runtime Error if an empty password is submitted' do
				data = Hash["old_password", "password", "new_password", ""]

				assert_raises RuntimeError do
					Postoffice::LoginService.reset_password @person.id, data
				end
			end

			it 'must raise a Runtime Error if no new password is submitted' do
				data = Hash["old_password", "password"]

				assert_raises RuntimeError do
					Postoffice::LoginService.reset_password @person.id, data
				end
			end

			it 'must raise a Runtime Error if the new password matches the old password' do
				data = Hash["old_password", "password", "new_password", ""]

				assert_raises RuntimeError do
					Postoffice::LoginService.reset_password @person.id, data
				end
			end

		end

	end

end

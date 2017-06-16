require_relative '../../spec_helper'

describe Postoffice::LoginService do

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

			describe 'check facebook login' do

				before do

					@test_facebook_email = 'open_plpraxu_user@tfbnw.net'
					@test_access_token = 'CAAF497CdlJ0BAAUpW0GvmWIEOSRnZCmNpNeepiNPtQSYKvaGx6xJoFrfbYVjN9DNz0kIZBuGS32YyAqtYgy2Tbuz6aK47reSVITyVcfOqje2scIumld6ff2FUByZAS93MSZBWTZBnyIqpmZAtr4YZCwl1kSlYFEUljOVU9BjPmaCmVDFZAwsqAFzPVZCqdgjFZCbee8vzH15k4lgZDZD'
					@test_facebook_id = '117936888576358'
					@test_password = 'postoffice'

					if Postoffice::Person.where(email: @test_facebook_email).count == 0
						create(:person, username: random_username, email: @test_facebook_email)
					end

					@fb_user = Postoffice::Person.find_by(email: @test_facebook_email)

				end

				describe 'get user details from facebook' do

					it 'must return a hash with the user details if a valid access token is used' do
						result = Postoffice::LoginService.get_user_details_from_facebook @test_access_token
						result.must_be_instance_of Hash
					end

					it 'must include the email for the user' do
						result = Postoffice::LoginService.get_user_details_from_facebook @test_access_token
						result['email'].must_equal @test_facebook_email
					end

					it 'must return nil if an invalid token is used' do
						result = Postoffice::LoginService.get_user_details_from_facebook "abc"
						result.must_equal nil
					end

				end

				describe 'authenticate facebook user' do

					it 'must return true if the user is successfully authenticated' do
						Postoffice::LoginService.authenticate_fb_user(@test_access_token, @test_facebook_email).must_equal true
					end

					it 'must return false if an invalid token is submitted' do
						Postoffice::LoginService.authenticate_fb_user('abc', @test_facebook_email).must_equal false
					end

					it 'must return false if the id does not match the id returned' do
						Postoffice::LoginService.authenticate_fb_user(@test_access_token, '123').must_equal false
					end

				end

				describe 'check facebook login' do

					describe 'sucessful login' do

						before do
							@data = JSON.parse('{"fb_access_token": "' + @test_access_token + '", "email": "' + @test_facebook_email + '"}')
							@person = Postoffice::LoginService.check_facebook_login @data
						end

						it 'must return a Person' do
							@person.must_be_instance_of Postoffice::Person
						end

						it 'must return the correct person' do
							@person.email.must_equal @test_facebook_email
						end

					end

					it 'must return nil if the authentication fails' do
						data = JSON.parse('{"fb_access_token": "' + 'abc' + '", "email": "' + @test_facebook_email + '"}')
 						Postoffice::LoginService.check_facebook_login(data).must_equal nil
					end

					it 'must return nil if the person record does not exist yet' do
						Postoffice::Person.find_by(email: @test_facebook_email).delete
						data = JSON.parse('{"fb_access_token": "' + @test_access_token + '", "email": "' + @test_facebook_email + '"}')
						person = Postoffice::LoginService.check_facebook_login data
						person.must_equal nil
					end

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

		describe 'reset password for a person' do

			it 'must set the hashed password using the new password and a salt' do
				new_password = "password123"
				Postoffice::LoginService.reset_password @person, new_password
				updated_record = Postoffice::Person.find(@person.id)
				updated_record.hashed_password.must_equal Postoffice::LoginService.hash_password new_password, updated_record.salt
			end


		end

		describe 'user resets the password' do

			it 'must store the new hashed password and salt if the correct old password is submitted' do
				data = Hash["old_password", "password", "new_password", "password123"]
				Postoffice::LoginService.password_reset_by_user @person.id, data

				person = Postoffice::Person.find(@person.id)
				person.hashed_password.must_equal Postoffice::LoginService.hash_password "password123", person.salt
			end

			it 'must raise a Runtime Error if an incorrect password is submitted' do
				data = Hash["old_password", "wrongpassword", "new_password", "password123"]

				assert_raises RuntimeError do
					Postoffice::LoginService.password_reset_by_user @person.id, data
				end
			end

			it 'must raise a Runtime Error if an empty password is submitted' do
				data = Hash["old_password", "password", "new_password", ""]

				assert_raises RuntimeError do
					Postoffice::LoginService.password_reset_by_user @person.id, data
				end
			end

			it 'must raise a Runtime Error if no new password is submitted' do
				data = Hash["old_password", "password"]

				assert_raises RuntimeError do
					Postoffice::LoginService.password_reset_by_user @person.id, data
				end
			end

			it 'must raise a Runtime Error if the new password matches the old password' do
				data = Hash["old_password", "password", "new_password", ""]

				assert_raises RuntimeError do
					Postoffice::LoginService.password_reset_by_user @person.id, data
				end
			end

		end

	end

end

require 'securerandom'
require 'digest'
require 'digest/bubblebabble'

module Postoffice

	class LoginService

		def self.salt
			SecureRandom.hex(64)
		end

		def self.append_salt string, salt
			string + salt
		end

		def self.hash_string string
			Digest::SHA256.bubblebabble string
		end

		def self.hash_password password, salt
			self.hash_string self.append_salt(password, salt)
		end

		# Currently letting user log in with username or email and sending this to the server as "username". This function looks in both username and email to find a match.
		def self.find_person_record_from_login username_or_email
			begin
				person = Postoffice::Person.find_by(username: username_or_email)
				return person
			rescue Mongoid::Errors::DocumentNotFound
			end

			begin
				person = Postoffice::Person.find_by(email: username_or_email)
				return person
			rescue Mongoid::Errors::DocumentNotFound
				return nil
			end

		end

		def self.check_login data
			person = self.find_person_record_from_login data["username"]
			if person && person.hashed_password == self.hash_password(data["password"], person.salt)
				return person
			else
				return nil
			end
		end

		def self.check_facebook_login data
			fb_user_authenticated = self.authenticate_fb_user data["fb_access_token"], data["email"]
			if fb_user_authenticated
				begin
					return Postoffice::Person.find_by(email: data["email"])
				rescue Mongoid::Errors::DocumentNotFound
				end
			end
			nil
		end

		def self.authenticate_fb_user user_access_token, email
			facebook_user_details = self.get_user_details_from_facebook user_access_token
			if facebook_user_details && facebook_user_details["email"] == email
				true
			else
				false
			end
		end

		def self.get_user_details_from_facebook user_access_token
			begin
				JSON.parse(RestClient.get "https://graph.facebook.com/me?fields=email&access_token=#{user_access_token}")
			rescue RestClient::BadRequest
				nil
			end
		end

		def self.response_for_successful_login person
			token = Postoffice::AuthService.generate_token_for_person person
			exp_in = 3600 * 24 * 72
			person_json = person.as_document.to_json( :except => ["salt", "hashed_password", "device_token"] )
			response = '{"access_token": "' + token + '", "token_type": "bearer", "expires_in": "' + exp_in.to_s + '", "person": ' + person_json + '}'
			response
		end

		def self.reset_password person, password
			salt = Postoffice::LoginService.salt
			person.salt = salt
			person.hashed_password = Postoffice::LoginService.hash_password password, salt
			person.save
		end

		def self.password_reset_by_user id, data

			person = Postoffice::Person.find(id)

			if data["old_password"] == data["new_password"]
				raise "New password cannot equal existing password"
			elsif data["new_password"] == "" || data["new_password"] == nil
				raise "New password cannot be empty"
			elsif person.hashed_password != self.hash_password(data["old_password"], person.salt)
				raise "Existing password is incorrect"
			else
				self.reset_password person, data["new_password"]
			end

		end

	end

end

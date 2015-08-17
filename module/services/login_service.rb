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

		def self.response_for_successful_login person
			token = self.generate_token_for_person person
			exp_in = 3600 * 24 * 72
			person_json = person.as_document.to_json( :except => ["salt", "hashed_password", "device_token"] )
			response = '{"access_token": "' + token + '", "token_type": "bearer", "expires_in": "' + exp_in.to_s + '", "person": ' + person_json + '}'
			response
		end

		def self.reset_password id, data

			person = Postoffice::Person.find(id)

			if data["old_password"] == data["new_password"]
				raise "New password cannot equal existing password"
			elsif data["new_password"] == "" || data["new_password"] == nil
				raise "New password cannot be empty"
			elsif person.hashed_password != self.hash_password(data["old_password"], person.salt)
				raise "Existing password is incorrect"
			else
				salt = Postoffice::LoginService.salt
				person.salt = salt
				person.hashed_password = Postoffice::LoginService.hash_password data["new_password"], salt
				person.save
			end

		end

		def self.get_private_key
			pem = File.read 'certificates/private_key.pem'
			key = OpenSSL::PKey::RSA.new pem, ENV['POSTOFFICE_KEYWORD']
			key
		end

		def self.get_public_key
			pem = File.read 'certificates/public_key.pem'
			OpenSSL::PKey::RSA.new pem
		end

		def self.generate_expiration_date_for_token
			#Generate a date that is 3 months in the future
			Time.now.to_i + 3600 * 24 * 72
		end

		def self.generate_payload_for_person person
			exp = self.generate_expiration_date_for_token
			{:id => person.id.to_s, :exp => exp}
		end

		def self.generate_token_for_person person
			payload = self.generate_payload_for_person person
			rsa_private = self.get_private_key
			token = JWT.encode payload, rsa_private, 'RS256'
			token
		end

	end

end

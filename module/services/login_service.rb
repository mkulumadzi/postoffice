require 'securerandom'
require 'digest'
require 'digest/bubblebabble'

module SnailMail

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
				person = SnailMail::Person.find_by(username: username_or_email)
				return person
			rescue Mongoid::Errors::DocumentNotFound
			end

			begin
				person = SnailMail::Person.find_by(email: username_or_email)
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

	end

end
require 'securerandom'
require 'digest'
require 'digest/bubblebabble'

module SnailMail

	class PersonService

		def self.get_people params = {}
			people = []
			SnailMail::Person.where(params).each do |person|
				people << person.as_document
			end
			people
		end

		def self.create_person data

			salt = nil
			hashed_password = nil

			if data["password"]
				salt = self.salt
				hashed_password = self.hash_password data["password"], salt 
			end

			phone = nil
			if data["phone"]
				phone = self.format_phone_number data["phone"]
			end

			SnailMail::Person.create!({
		      username: data["username"],
		      name: data["name"],
		      email: data["email"],
		      phone: phone,
		      address1: data["address1"],
		      city: data["city"],
		      state: data["state"],
		      zip: data["zip"],
		      salt: salt,
		      hashed_password: hashed_password,
		      device_token: data["device_token"]
		    })
		end

		def self.format_phone_number phone
			phone.tr('^0-9', '')
		end

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
				return true
			else
				return false
			end
		end

		def self.update_person person_id, data
			person = SnailMail::Person.find(person_id)

			if data["username"]
				raise ArgumentError
			end

			person.update_attributes!(data)

		end

	end

end
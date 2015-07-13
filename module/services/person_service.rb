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

			SnailMail::Person.create!({
		      username: data["username"],
		      name: data["name"],
		      email: data["email"],
		      phone: data["phone"],
		      address1: data["address1"],
		      city: data["city"],
		      state: data["state"],
		      zip: data["zip"],
		      salt: salt,
		      hashed_password: hashed_password,
		      device_token: data["device_token"]
		    })
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

		def self.get_person_for_username username
			returned_person = nil
			SnailMail::Person.where(username: username).each do |person|
				returned_person = person
			end
			returned_person
		end

		def self.check_login data
			@person_match = self.get_person_for_username data["username"]
			if @person_match
				if @person_match.hashed_password == self.hash_password(data["password"], @person_match.salt)
					return true
				else
					return false
				end
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
require 'SecureRandom'
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
		      address1: data["address1"],
		      city: data["city"],
		      state: data["state"],
		      zip: data["zip"],
		      salt: salt,
		      hashed_password: hashed_password
		    })
		end

		def self.salt
			SecureRandom.hex(64)
		end

		def self.append_salt string, salt
			string.concat(salt)
		end

		def self.hash_string string
			Digest::SHA256.bubblebabble string
		end

		def self.hash_password password, salt
			appended = self.append_salt password, salt
			self.hash_string appended
		end

	end

end
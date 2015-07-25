require 'securerandom'
require 'digest'
require 'digest/bubblebabble'

module SnailMail

	class PersonService

		def self.create_person data

			salt = nil
			hashed_password = nil

			if data["password"]
				salt = SnailMail::LoginService.salt
				hashed_password = SnailMail::LoginService.hash_password data["password"], salt 
			end

			if data["phone"]
				phone = self.format_phone_number data["phone"]
			end

			self.validate_required_fields data

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

		def self.validate_required_fields data
			if data["username"] == nil || data["username"] == ""
				raise "Missing required field: username"
			elsif data["email"] == nil || data["email"] == ""
				raise "Missing required field: email"
			elsif SnailMail::Person.where(email: data["email"]).exists?
				raise "An account with that email already exists!"
			elsif data["phone"] == nil || data["phone"] == ""
				raise "Missing required field: phone"
			elsif SnailMail::Person.where(phone: data["phone"]).exists?
				raise "An account with that phone number already exists!"
			elsif data["password"] == nil || data["password"] == ""
				raise "Missing required field: password"
			end
		end

		def self.format_phone_number phone
			phone.tr('^0-9', '')
		end

		# def self.salt
		# 	SecureRandom.hex(64)
		# end

		# def self.append_salt string, salt
		# 	string + salt
		# end

		# def self.hash_string string
		# 	Digest::SHA256.bubblebabble string
		# end

		# def self.hash_password password, salt
		# 	self.hash_string self.append_salt(password, salt)
		# end

		# # Currently letting user log in with username or email and sending this to the server as "username". This function looks in both username and email to find a match.
		# def self.find_person_record_from_login username_or_email
		# 	begin
		# 		person = SnailMail::Person.find_by(username: username_or_email)
		# 		return person
		# 	rescue Mongoid::Errors::DocumentNotFound
		# 	end

		# 	begin
		# 		person = SnailMail::Person.find_by(email: username_or_email)
		# 		return person
		# 	rescue Mongoid::Errors::DocumentNotFound
		# 		return nil
		# 	end

		# end

		# def self.check_login data
		# 	person = self.find_person_record_from_login data["username"]
		# 	if person && person.hashed_password == self.hash_password(data["password"], person.salt)
		# 		return person
		# 	else
		# 		return nil
		# 	end
		# end

		def self.update_person person_id, data
			person = SnailMail::Person.find(person_id)

			if data["username"]
				raise ArgumentError
			end

			person.update_attributes!(data)

		end

		def self.get_people params = {}
			people = []
			SnailMail::Person.where(params).each do |person|
				people << person.as_document
			end
			people
		end

		def self.search_people params
			people = []
			search_term = self.format_search_term(params["term"])

			if params["limit"]
				search_limit = params["limit"]
			else
				search_limit = 25
			end

			SnailMail::Person.or({name: /#{search_term}/}, {username: /#{search_term}/}).limit(search_limit).each do |person|
				people << person
			end

			people
		end

		def self.format_search_term term
			term.gsub("+", " ")
		end

		#Search array is expected to contain JSON objects with a reference to the name of the person, and an array for emails and phone numbers
		def self.bulk_search search_term_array

			people = []

			search_term_array.each do |entry|

				self.get_people_from_email_array(entry["emails"]).each do |person|
					people << person
				end

				self.get_people_from_phone_array(entry["phoneNumbers"]).each do |person|
					people << person
				end

			end

			people.uniq

		end

		def self.get_people_from_email_array email_array
			people = []

			email_array.each do |email|
				SnailMail::Person.where(email: email).each do |person|
					people << person
				end
			end

			people
		end

		def self.get_people_from_phone_array phone_array
			people = []

			phone_array.each do |phone|
				phone = self.format_phone_number phone
				SnailMail::Person.where(phone: phone).each do |person|
					people << person
				end
			end

			people
		end

	end

end
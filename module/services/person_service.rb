require 'securerandom'
require 'digest'
require 'digest/bubblebabble'

module Postoffice

	class PersonService

		def self.create_person data

			salt = nil
			hashed_password = nil

			if data["password"]
				salt = Postoffice::LoginService.salt
				hashed_password = Postoffice::LoginService.hash_password data["password"], salt
			end

			if data["phone"]
				phone = self.format_phone_number data["phone"]
			end

			self.validate_required_fields data

			Postoffice::Person.create!({
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
			elsif Postoffice::Person.where(email: data["email"]).exists?
				raise "An account with that email already exists!"
			elsif data["phone"] == nil || data["phone"] == ""
				raise "Missing required field: phone"
			elsif Postoffice::Person.where(phone: data["phone"]).exists?
				raise "An account with that phone number already exists!"
			elsif data["password"] == nil || data["password"] == ""
				raise "Missing required field: password"
			end
		end

		def self.format_phone_number phone
			phone.tr('^0-9', '')
		end

		def self.update_person person_id, data
			person = Postoffice::Person.find(person_id)

			if data["username"]
				raise ArgumentError
			end

			person.update_attributes!(data)

		end

		def self.get_people params = {}
			people = []
			Postoffice::Person.where(params).each do |person|
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

			Postoffice::Person.or({name: /#{search_term}/}, {username: /#{search_term}/}).limit(search_limit).each do |person|
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
				Postoffice::Person.where(email: email).each do |person|
					people << person
				end
			end

			people
		end

		def self.get_people_from_phone_array phone_array
			people = []

			phone_array.each do |phone|
				phone = self.format_phone_number phone
				Postoffice::Person.where(phone: phone).each do |person|
					people << person
				end
			end

			people
		end

	end

end

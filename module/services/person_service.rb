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
					given_name: data["given_name"],
					family_name: data["family_name"],
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
			elsif Postoffice::Person.where(phone: data["phone"]).exists? && data["phone"] != "" && data["phone"] != nil
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
			query = self.create_query_for_search_term params["term"]

			if params["limit"]
				search_limit = params["limit"]
			else
				search_limit = 25
			end

			query.limit(search_limit).each { |person| people << person }
			people
		end

		def self.create_query_for_search_term term
			search_terms = term.split('+')
			if search_terms.length == 1
				Postoffice::Person.or({given_name: /#{term}/}, {family_name: /#{term}/}, {username: /#{term}/})
			else
				first_term = search_terms[0]
				second_term = search_terms[1]
				Postoffice::Person.or({given_name: /#{first_term}/, family_name: /#{second_term}/},{given_name: /#{second_term}/, family_name: /#{first_term}/})
			end
		end

		# def self.format_search_term term
		# 	term.gsub("+", " ")
		# end

		def self.find_people_from_list_of_emails email_array
			people = []
			email_array.each do |email|
				if Postoffice::Person.where(email: email).count > 0
					people << Postoffice::Person.where(email: email).first
				end
			end
			people
		end

		def self.check_field_availability params
			fields_that_can_be_checked = ["username", "phone", "email"]
			if params.count > 1
				raise "Only one field may be checked at a time"
			elsif fields_that_can_be_checked.index(params.keys[0]) == nil
				raise "#{params.keys[0]} cannot be checked"
			else
				begin
					Postoffice::Person.find_by(params)
					return Hash[params.keys[0], "unavailable"]
				rescue Mongoid::Errors::DocumentNotFound
					return Hash[params.keys[0], "available"]
				end
			end

		end

	end

end

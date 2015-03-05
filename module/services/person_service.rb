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
			SnailMail::Person.create!({
		      username: data["username"],
		      name: data["name"],
		      address1: data["address1"],
		      city: data["city"],
		      state: data["state"],
		      zip: data["zip"]
		    })
		end

	end

end
module SnailMail
	class Person

		def self.get_people params = {}
			people = []
			SnailMail::Person.where(params).each do |person|
				people << person.as_document
			end
			people
		end

	end
end
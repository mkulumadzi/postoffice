# Fix person records where email is stored as the username
email_as_username = Postoffice::Person.where(email: nil, :username => /@/)

puts "\nFound #{email_as_username.count} person records with username storing email address"

# Moving email into 'email' field and using portion before @ symbol as username
email_as_username.each do |doc|
	doc.email = doc.username
	doc.username = doc.username.split('@')[0]

	puts ">> Changing username to #{doc.username} and email to #{doc.email}"
	doc.save! rescue puts "Could not modiy doc #{doc.id}/#{doc.username}"

end

#Fix mail with 'to' person orphaned by migrating usernames to email field
email_as_to = Postoffice::Mail.where(:to => /@/)

puts "\nFound #{email_as_to.count} records with 'to' field storing an email address"

email_as_to.each do |doc|

	if person = Postoffice::Person.find_by(email: doc.to)
		puts ">> Changing 'to' field from #{doc.to} to #{person.username}"
		doc.to = person.username
		doc.save! rescue puts "Could not modiy doc #{doc.id}/#{doc.to}"
	end

end

#Fix mail with 'from' person orphaned by migrating usernames to email field
email_as_from = Postoffice::Mail.where(:from => /@/)

puts "\nFound #{email_as_from.count} records with 'from' field storing an email address"

email_as_from.each do |doc|

	if person = Postoffice::Person.find_by(email: doc.from)
		puts ">> Changing 'from' field from #{doc.from} to #{person.username}"
		doc.from = person.username
		doc.save! rescue puts "Could not modiy doc #{doc.id}/#{doc.from}"
	end

end

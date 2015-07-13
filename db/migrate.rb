# Person records where email is stored as the username
email_as_username = SnailMail::Person.where(email: nil, :username => /@/)

puts "Modifying #{email_as_username.count} records..."

# Moving email into 'email' field and using portion before @ symbol as username
email_as_username.each do |doc|

	doc.email = doc.username
	doc.username = doc.username.split('@')[0]

	doc.save! rescue puts "Could not modiy doc #{doc.id}/#{doc.username}"

end
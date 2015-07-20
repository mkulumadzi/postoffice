# Convenience methods for converting person amd mail objects into JSON objects that can be posted
def random_username
	(0...8).map { (65 + rand(26)).chr }.join
end

def random_phone
	number = rand(9999999999)
	number.to_s
end

def random_email
	username = (0...8).map { (65 + rand(26)).chr }.join
	username + "@test.com"
end

def convert_person_to_json person
	person.as_document.to_json
end

def convert_mail_to_json mail
	mail.as_document.to_json
end

def expected_json_fields_for_person person
	JSON.parse(person.as_document.to_json( :except => ["salt", "hashed_password", "device_token"] ))
end

def expected_json_fields_for_mail mail
	JSON.parse(mail.as_document.to_json)
end

def get_mail_object_from_mail_response mail_response
	mail_id = mail_response["_id"]["$oid"]
	mail = SnailMail::Mail.find(mail_id)
end

def get_person_object_from_person_response person_response
	person_id = person_response["_id"]["$oid"]
	person = SnailMail::Person.find(person_id)
end
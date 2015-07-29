require_relative 'module/postoffice'


get '/' do
  "Hello World!"
end

# Create a new person
post '/person/new' do
  content_type :json

  data = JSON.parse request.body.read

  begin
    person = SnailMail::PersonService.create_person data
    SnailMail::MailService.generate_welcome_message person

    person_link = "#{ENV['SNAILMAIL_BASE_URL']}/person/id/#{person.id}"

    status = 201
    headers = { "location" => person_link }
  rescue Moped::Errors::OperationFailure => error
    status = 403

    #To Do: Generate this message dynamically based on the type of violation
    response_body = Hash["message", "An account with that username already exists!"].to_json
  rescue RuntimeError => error
    status = 403
    response_body = Hash["message", error.to_s].to_json
  end

  [status, headers, response_body]

end

post '/login' do
  content_type :json

  data = JSON.parse request.body.read

  begin
    person = SnailMail::LoginService.check_login data
    if person
      status = 200
      response_body = person.as_document.to_json( :except => ["salt", "hashed_password", "device_token"] )
    else
      status = 401
    end
  rescue Mongoid::Errors::DocumentNotFound
    status = 401
  end

  [status, response_body]

end

# Retrieve a single person record
get '/person/id/:id' do
  content_type :json
  begin
    person = SnailMail::Person.find(params[:id])
    status = 200
    response_body = person.as_document.to_json( :except => ["salt", "hashed_password", "device_token"] )
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]
end

# Update a person record
post '/person/id/:id' do

  data = JSON.parse request.body.read

  begin
    SnailMail::PersonService.update_person params[:id], data
    status = 204
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
  rescue Moped::Errors::OperationFailure
    status = 403
  rescue ArgumentError
    status = 403
  end

  [status, nil]

end

post '/person/id/:id/reset_password' do
  content_type :json
  data = JSON.parse request.body.read

  begin
    SnailMail::LoginService.reset_password params[:id], data
    status = 204
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
  rescue RuntimeError => error
    status = 403
    response_body = Hash["message", error.to_s].to_json
  end

  [status, nil, response_body]

end

# View records for all people in the database.
# Filtering implemented, for example: /people?username=bigedubs
get '/people' do
  content_type :json
  response_body = SnailMail::PersonService.get_people(params).to_json( :except => ["salt", "hashed_password", "device_token"] )
  [200, response_body]
end

get '/people/search' do

  content_type :json

  begin
    people_returned = SnailMail::PersonService.search_people params

    people_bson = []
    people_returned.each do |person|
      people_bson << person.as_document
    end

    response_body = people_bson.to_json( :except => ["salt", "hashed_password", "device_token"] )
    status = 200
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
  end

  [status, response_body]

end

# Do a bulk search of people (for example, when searching for contacts from a phone who are registered users of the service)
post '/people/bulk_search' do
  content_type :json
  data = JSON.parse request.body.read

  begin
    people = SnailMail::PersonService.bulk_search data

    people_bson = []
    people.each do |person|
      people_bson << person.as_document
    end

    response_body = people_bson.to_json( :except => ["salt", "hashed_password", "device_token"] )
    status = 200
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
  end

  [status, response_body]

end

# Creae a new piece of mail
# Mail from field is interpreted by the ID in the URI
post '/person/id/:id/mail/new' do
  data = JSON.parse request.body.read

  begin
    mail = SnailMail::MailService.create_mail params[:id], data
    mail_link = "#{ENV['SNAILMAIL_BASE_URL']}/mail/id/#{mail.id}"
    headers = { "location" => mail_link }
    status = 201
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    headers = nil
  rescue Moped::Errors::OperationFailure
    status = 403
    headers = nil
  end

  [status, headers, nil]

end

# TO DO: Implement feature enabling mail to be sent right away (rather than entering a 'draft' state.)

post '/person/id/:id/mail/send' do
  data = JSON.parse request.body.read

  begin
    mail = SnailMail::MailService.create_mail params[:id], data
    mail.mail_it
    mail_link = "#{ENV['SNAILMAIL_BASE_URL']}/mail/id/#{mail.id}"
    headers = { "location" => mail_link }
    status = 201
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    headers = nil
  rescue Moped::Errors::OperationFailure
    status = 403
    headers = nil
  end

  [status, headers, nil]

end

# Retrieve a piece of mail
get '/mail/id/:id' do
  content_type :json

  begin
    mail = SnailMail::Mail.find(params[:id])
    status = 200
    response_body = mail.as_document.to_json
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]

end

# View all mail in the system
get '/mail' do
  content_type :json
  response_body = SnailMail::MailService.get_mail(params).to_json
  [200, response_body]
end

# Send a piece of mail
# Known issue: You can send mail to an invalid username (not sure if this needs to be fixed)
post '/mail/id/:id/send' do

  begin
    mail = SnailMail::Mail.find(params[:id])
    mail.mail_it
    status = 204
    response_body = nil
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  rescue ArgumentError
    status = 403
    response_body = nil
  end

  [status, response_body]

end

# Deliver a piece of mail
post '/mail/id/:id/deliver' do

   begin
    mail = SnailMail::Mail.find(params[:id])
    mail.deliver_now
    status = 204
    response_body = nil
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  rescue ArgumentError
    status = 403
    response_body = nil
  end

  [status, response_body]

end

# Mark a piece of mail as read
post '/mail/id/:id/read' do

  begin
    mail = SnailMail::Mail.find(params[:id])
    mail.read
    status = 204
    response_body = nil
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  rescue ArgumentError
    status = 403
    response_body = nil
  end

  [status, response_body]

end

# View delivered mail for a person
get '/person/id/:id/mailbox' do
  content_type :json

  begin
    response_body = SnailMail::MailService.mailbox(params).to_json
    status = 200
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]

end

# View sent mail
get '/person/id/:id/outbox' do
  content_type :json

  begin
    response_body = SnailMail::MailService.outbox(params).to_json
    status = 200
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]

end

# Get a list of people a person has sent mail to or received mail from
get '/person/id/:id/contacts' do
  content_type :json

  begin
    person = SnailMail::Person.find(params["id"])
    response_body = SnailMail::MailService.get_contacts(person.username).to_json( :except => ["salt", "hashed_password", "device_token"] )
    status = 200
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]

end

put '/upload' do

  file = params["file"]
  filename = params["filename"]

  begin
    key = SnailMail::FileService.put_file file, filename
    headers = { "location" => key }
    status = 204
  rescue ArgumentError
    status = 403
  end

  [status, headers, nil]
end

get '/postcard/:uuid' do
  image_url = Dragonfly.app.remote_url_for("postcards/#{params["uuid"]}")
  Dragonfly.app.fetch_url(image_url).to_response
end

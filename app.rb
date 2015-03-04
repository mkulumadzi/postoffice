require_relative 'module/postoffice'


get '/' do
  "Hello World!"
end

# Create a new person
post '/person/new' do

  data = JSON.parse request.body.read

  begin
    person = SnailMail::Person.create!({
      username: data["username"],
      name: data["name"],
      address1: data["address1"],
      city: data["city"],
      state: data["state"],
      zip: data["zip"]
    })

    person_link = "http://localhost:9292/person/id/#{person.id}"
    headers = { "location" => person_link }
    status = 201
  rescue Moped::Errors::OperationFailure
    status = 403
    headers = nil
  end

  [status, headers, nil]

end

# Retrieve a single person record
get '/person/id/:id' do
  content_type :json
  begin
    person = SnailMail::Person.find(params[:id])
    status = 200
    response_body = person.as_document.to_json
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]
end

# View records for all people in the database.
# Filtering implemented, for example: /people?username=bigedubs
get '/people' do
  content_type :json
  response_body = SnailMail::Person.get_people(params).to_json
  [200, response_body]
end

# Creae a new piece of mail
# Mail from is interpreted by the ID in the URI
post '/person/id/:id/mail/new' do
  begin
    person = SnailMail::Person.find_by(_id: params[:id])
    data = JSON.parse request.body.read

    mail = SnailMail::Mail.create!({
      from: person.username,
      to: data["to"],
      content: data["content"]
    })

    mail_link = "http://localhost:9292/mail/id/#{mail.id}"
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
  response_body = SnailMail::Mail.get_mail(params).to_json
  [200, response_body]
end

# View delivered mail for a person
get '/person/id/:id/mailbox' do
  content_type :json

  begin
    response_body = SnailMail::Mail.mailbox(params).to_json
    status = 200
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]

end
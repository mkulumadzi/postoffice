require_relative 'module/postoffice'

# Convenience Methods
def add_since_to_request_parameters app
  if app.request.env["HTTP_SINCE"]
    utc_date = Time.parse(env["HTTP_SINCE"])
    app.params[:updated_at] = { "$gt" => utc_date }
  end
end

def get_token_from_authorization_header request
  token_header = request.env["HTTP_AUTHORIZATION"]
  token_header.split(' ')[1]
end

def get_payload_from_authorization_header request
  if request.env["HTTP_AUTHORIZATION"] != nil
    begin
      token = get_token_from_authorization_header request
      decoded_token = Postoffice::AuthService.decode_token token
      payload = decoded_token[0]
    rescue JWT::ExpiredSignature
      "Token expired"
    rescue JWT::VerificationError
      "Invalid token signature"
    rescue JWT::DecodeError
      "Token is invalid"
    end
  else
    "No token provided"
  end
end

def unauthorized request, required_scope
  payload = get_payload_from_authorization_header request
  if payload["scope"] == nil
    return true
  elsif payload["scope"].include? required_scope
    return false
  else
    return true
  end
end

def not_authorized_owner request, required_scope, person_id
  payload = get_payload_from_authorization_header request
  id = payload["id"]

  if payload["scope"] == nil
    return true
  elsif payload["scope"].include?(required_scope) && id == person_id
    return false
  else
    return true
  end
end

def get_api_version_from_content_type request
  content_type = request.env["CONTENT_TYPE"]
  if content_type && content_type.include?("application/vnd.postoffice")
    version = content_type.split('.').last.split('+')[0]
  else
    version = "v1"
  end
  version
end

get '/' do
  version = get_api_version_from_content_type request
  if version == "v2"
    "What a Beautiful Morning"
  else
    "Hello World!"
  end
end

options "*" do
  response.headers["Allow"] = "HEAD,GET,PUT,POST,DELETE,OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, Authorization"
  response.headers["Access-Control-Allow-Origin"] = "*"
  response.status = 200
end

# Create a new person
# Scope: create-person
post '/person/new' do
  content_type :json

  if unauthorized(request, "create-person")
    return [401, nil, nil]
  end

  begin
    data = JSON.parse request.body.read
    person = Postoffice::PersonService.create_person data
    Postoffice::MailService.generate_welcome_message person
    person_link = "#{ENV['POSTOFFICE_BASE_URL']}/person/id/#{person.id}"

    headers = { "location" => person_link }
    [201, headers, nil]
  rescue Moped::Errors::OperationFailure => error
    response_body = Hash["message", "An account with that username already exists!"].to_json
    [403, nil, response_body]
  rescue RuntimeError => error
    status = 403
    response_body = Hash["message", error.to_s].to_json
    [403, nil, response_body]
  end

end

# Check if a registration field such as username is available
# Scope: create-person
get '/available' do
  content_type :json

  if unauthorized(request, "create-person")
    return [401, nil, nil]
  end

  begin
    response_body = Postoffice::PersonService.check_field_availability(params).to_json
    [200, response_body]
  rescue RuntimeError
    [404, nil]
  end
end

# Login and return an oauth token if successful
# Scope: nil
post '/login' do
  content_type :json
  begin
    data = JSON.parse request.body.read
    person = Postoffice::LoginService.check_login data
    if person
      response_body = Postoffice::LoginService.response_for_successful_login person
      [200, response_body]
    else
      [401, nil]
    end
  rescue Mongoid::Errors::DocumentNotFound
    [401, nil]
  end
end

# Retrieve a single person record
# Scope: can-read
get '/person/id/:id' do
  content_type :json

  if unauthorized(request, "can-read")
    return [401, nil, nil]
  end

  begin
    person = Postoffice::Person.find(params[:id])
    response_body = person.as_document.to_json( :except => ["salt", "hashed_password", "device_token"] )
    [200, response_body]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  end

end

# Update a person record
# Scope: admin or (can_write & is person)
post '/person/id/:id' do
  begin
    data = JSON.parse request.body.read

    if unauthorized(request, "admin") && not_authorized_owner(request, "can-write", params[:id])
      return [401, nil, nil]
    end

    Postoffice::PersonService.update_person params[:id], data
    [204, nil]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  rescue Moped::Errors::OperationFailure
    [403, nil]
  rescue ArgumentError
    [403, nil]
  end
end

# Reset a password for a user
# Scope: reset-password
post '/person/id/:id/reset_password' do
  content_type :json

  if unauthorized(request, "reset-password")
    return [401, nil, nil]
  end

  begin
    data = JSON.parse(request.body.read)
    Postoffice::LoginService.password_reset_by_user params[:id], data
    [204, nil]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  rescue RuntimeError => error
    response_body = Hash["message", error.to_s].to_json
    [403, response_body]
  end

end

# Reset password using a temporary token, via a webapp
post '/reset_password' do
  content_type :json
  cross_origin

  begin

    # Check the token
    if unauthorized(request, "reset-password")
      return [401, nil]
    else

      token = get_token_from_authorization_header request
      if Postoffice::AuthService.token_is_invalid(token)
        return [401, nil]
      end

      data = JSON.parse(request.body.read)
      if data["password"] == nil
        return [403, nil]
      end

      payload = get_payload_from_authorization_header request
      person = Postoffice::Person.find(payload["id"])
      Postoffice::LoginService.reset_password person, data["password"]

      db_token = Postoffice::Token.new(value: token)
      db_token.mark_as_invalid

      [204, nil]
    end
  end

end

# View records for all people in the database.
# Filtering implemented, for example: /people?username=bigedubs
# Scope: admin
get '/people' do

  if unauthorized(request, "admin")
    return [401, nil, nil]
  end

  content_type :json
  add_since_to_request_parameters self
  response_body = Postoffice::PersonService.get_people(params).to_json( :except => ["salt", "hashed_password", "device_token"] )
  [200, response_body]

end

# Search people by username or name
# Scope: can-read
get '/people/search' do
  content_type :json

  if unauthorized(request, "can-read")
    return [401, nil, nil]
  end

  begin
    people_returned = Postoffice::PersonService.search_people params

    people_bson = []
    people_returned.each do |person|
      people_bson << person.as_document
    end

    response_body = people_bson.to_json( :except => ["salt", "hashed_password", "device_token"] )
    [200, response_body]
  rescue Mongoid::Errors::DocumentNotFound
    [404, response_body]
  end

end

# Do a bulk search of people (for example, when searching for contacts from a phone who are registered users of the service)
# Scope: can-read
post '/people/bulk_search' do
  content_type :json

  if unauthorized(request, "can-read")
    return [401, nil, nil]
  end

  begin
    data = JSON.parse request.body.read
    people = Postoffice::PersonService.bulk_search data

    people_bson = []
    people.each do |person|
      people_bson << person.as_document
    end

    response_body = people_bson.to_json( :except => ["salt", "hashed_password", "device_token"] )
    [200, response_body]
  rescue Mongoid::Errors::DocumentNotFound
    [404, response_body]
  end

end

# Creae a new piece of mail
# Mail from field is interpreted by the ID in the URI
# Scope: admin OR (can-write, is the person)
post '/person/id/:id/mail/new' do
  data = JSON.parse request.body.read

  if unauthorized(request, "admin") && not_authorized_owner(request, "can-write", params[:id])
    return [401, nil, nil]
  end

  begin
    mail = Postoffice::MailService.create_mail params[:id], data
    mail_link = "#{ENV['POSTOFFICE_BASE_URL']}/mail/id/#{mail.id}"
    headers = { "location" => mail_link }
    [201, headers, nil]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil, nil]
  rescue Moped::Errors::OperationFailure
    [403, nil, nil]
  end

end

# Send mail right away, without creating draft state
# Scope: admin OR (can-write, is person)
post '/person/id/:id/mail/send' do
  data = JSON.parse request.body.read

  if unauthorized(request, "admin") && not_authorized_owner(request, "can-write", params[:id])
    return [401, nil, nil]
  end

  begin
    mail = Postoffice::MailService.create_mail params[:id], data
    mail.mail_it
    mail_link = "#{ENV['POSTOFFICE_BASE_URL']}/mail/id/#{mail.id}"
    headers = { "location" => mail_link }
    [201, headers, nil]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  rescue Moped::Errors::OperationFailure
    [403, nil]
  end

end

# Retrieve a piece of mail
# Scope: admin OR (can-read, is to or from person)
get '/mail/id/:id' do
  content_type :json

  begin
    mail = Postoffice::Mail.find(params[:id])

    from_id = Postoffice::Person.find_by(username: mail.from).id.to_s
    to_id = Postoffice::Person.find_by(username: mail.to).id.to_s

    if unauthorized(request, "admin") && not_authorized_owner(request, "can-read", from_id) && not_authorized_owner(request, "can-read", to_id)
      return [401, nil, nil]
    end

    response_body = mail.as_document.to_json
    [200, response_body]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  end

end

# Retrieve image for a piece of mail
# Scope: admin OR (can-read, is to or from person)
get '/mail/id/:id/image' do

  begin
    mail = Postoffice::Mail.find(params[:id])
    if mail.image_uid == nil
      [404, nil, nil]
    else
      from_id = Postoffice::Person.find_by(username: mail.from).id.to_s
      to_id = Postoffice::Person.find_by(username: mail.to).id.to_s

      if unauthorized(request, "admin") && not_authorized_owner(request, "can-read", from_id) && not_authorized_owner(request, "can-read", to_id)
        return [401, nil, nil]
      end

      Postoffice::FileService.fetch_image(mail.image_uid, params).to_response
    end
  rescue ArgumentError
    response_body = Hash["message", "Could not process thumbnail parameter."].to_json
    [403, nil, response_body]
  end

end

# View all mail in the system
# Scope: admin
get '/mail' do
  content_type :json

  if unauthorized(request, "admin")
    return [401, nil]
  end

  add_since_to_request_parameters self
  response_body = Postoffice::MailService.get_mail(params).to_json
  [200, response_body]
end

# Send a piece of mail
# Known issue: You can send mail to an invalid username (not sure if this needs to be fixed)
# Scope: admin OR (can_write, is 'from' person)
post '/mail/id/:id/send' do

  begin
    mail = Postoffice::Mail.find(params[:id])

    from_id = Postoffice::Person.find_by(username: mail.from).id.to_s
    if unauthorized(request, "admin") && not_authorized_owner(request, "can-write", from_id)
      return [401, nil]
    end

    mail.mail_it
    [204, nil]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  rescue ArgumentError
    [403, nil]
  end

end

# Deliver a piece of mail
# Scope: admin
post '/mail/id/:id/deliver' do

   begin
    mail = Postoffice::Mail.find(params[:id])

    from_id = Postoffice::Person.find_by(username: mail.from).id.to_s
    if unauthorized(request, "admin") && not_authorized_owner(request, "can-write", from_id)
      return [401, nil]
    end

    mail.deliver_now

    [204, nil]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  rescue ArgumentError
    [403, nil]
  end

end

# Mark a piece of mail as read
# Scope: admin OR (can_write, is 'from' person)
post '/mail/id/:id/read' do

  begin
    mail = Postoffice::Mail.find(params[:id])

    to_id = Postoffice::Person.find_by(username: mail.to).id.to_s
    if unauthorized(request, "admin") && not_authorized_owner(request, "can-write", to_id)
      return [401, nil]
    end

    mail.read
    [204, nil]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  rescue ArgumentError
    [403, nil]
  end

end

# View delivered mail for a person
# Scope: admin OR (can-read, is person)
get '/person/id/:id/mailbox' do
  content_type :json

  add_since_to_request_parameters self

  if unauthorized(request, "admin") && not_authorized_owner(request, "can-read", params[:id])
    return [401, nil, nil]
  end

  begin
    response_body = Postoffice::MailService.mailbox(params).to_json
    [200, response_body]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  end

end

# View sent mail
# Scope: admin OR (can-read, is person)
get '/person/id/:id/outbox' do
  content_type :json
  add_since_to_request_parameters self

  begin
    if unauthorized(request, "admin") && not_authorized_owner(request, "can-read", params[:id])
      return [401, nil, nil]
    end

    response_body = Postoffice::MailService.outbox(params).to_json
    [200, response_body]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  end

end

# Get a list of people a person has sent mail to or received mail from
# Scope: admin OR (can-read, is person)
get '/person/id/:id/contacts' do
  content_type :json

  if unauthorized(request, "admin") && not_authorized_owner(request, "can-read", params[:id])
    return [401, nil, nil]
  end

  begin
    person = Postoffice::Person.find(params["id"])
    response_body = Postoffice::MailService.get_contacts(person.username).to_json( :except => ["salt", "hashed_password", "device_token"] )
    [200, response_body]
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  end

end

# Upload a File
# Scope: can-write
post '/upload' do

  data = JSON.parse request.body.read.gsub("\n", "")

  if unauthorized(request, "can-write")
    return [401, nil, nil]
  end

  begin
    uid = Postoffice::FileService.upload_file data
    headers = { "location" => uid }
    [201, headers, nil]
  rescue ArgumentError => error
    response_body = Hash["message", error.to_s].to_json
    [403, nil, response_body]
  rescue RuntimeError => error
    response_body = Hash["message", error.to_s].to_json
    [403, nil, response_body]
  end

end

# Get a list of uids for postcards in the resources /cards bucket on AWS
# Scope: can-read
get '/cards' do
  content_type :json

  if unauthorized(request, "can-read")
    return [401, nil]
  end

  response_body = Postoffice::FileService.get_cards.to_json
  [200, response_body]

end

# Get a specific image
# Scope: can-read can get images in /resources only, admin can get any image
get '/image/*' do

  begin
    uid = params['splat'][0]

    if uid.include?("resources") == false && unauthorized(request, "admin")
      return [401, nil]
    elsif unauthorized(request, "can-read")
      return [401, nil]
    end

    name = uid.split('/').last
    image = Dragonfly.app.fetch(uid).encode('jpg')
    image.name = name
    image.to_response
  rescue Dragonfly::Job::Fetch::NotFound
    [404, nil, nil]
  end
end

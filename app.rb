require_relative 'module/postoffice'

get '/' do
  version = Postoffice::AppService.get_api_version_from_content_type request
  if version == "v2"
    "What a Beautiful Morning"
  else
    "Hello World!"
  end
end

options "*" do
  response.headers["Allow"] = "GET,POST,OPTIONS"
  response.headers["Access-Control-Allow-Headers"] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept, Authorization"
  response.headers["Access-Control-Allow-Origin"] = "*"
end

# Create a new person
# Scope: create-person
post '/person/new' do
  content_type :json
  data = JSON.parse request.body.read

  if Postoffice::AppService.unauthorized?(request, "create-person") then return [401, nil] end

  begin
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

  if Postoffice::AppService.unauthorized?(request, "create-person") then return [401, nil] end

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
  data = JSON.parse request.body.read
  begin
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
  if Postoffice::AppService.unauthorized?(request, "can-read") then return [401, nil] end

  begin
    person = Postoffice::Person.find(params[:id])
    person_response = person.as_document.to_json( :except => ["salt", "hashed_password", "device_token"] )

    if request.env["HTTP_IF_MODIFIED_SINCE"] == nil
      [200, person_response]
    else
      modified_since = Time.parse(env["HTTP_IF_MODIFIED_SINCE"])
      ## Converting to integer because the fractions of a second tend to mess this up, even for datetimes that are otherwise equivalent
      if person.updated_at.to_i > modified_since.to_i
        [200, person_response]
      else
        [304, nil]
      end
    end
  rescue Mongoid::Errors::DocumentNotFound
    [404, nil]
  end

end

# Update a person record
# Scope: admin or (can_write & is person)
post '/person/id/:id' do
  data = JSON.parse request.body.read
  if Postoffice::AppService.not_admin_or_owner?(request, "can-write", params[:id]) then return [401, nil] end
  begin
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
  data = JSON.parse(request.body.read)
  if Postoffice::AppService.unauthorized?(request, "reset-password") then return [401, nil] end

  begin
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
  data = JSON.parse(request.body.read)

  # Check the token
  if Postoffice::AppService.unauthorized?(request, "reset-password") then return [401, nil] end

  token = Postoffice::AppService.get_token_from_authorization_header request
  if Postoffice::AuthService.token_is_invalid(token) then return [401, nil] end

  if data["password"] == nil then return [403, nil] end

  payload = Postoffice::AppService.get_payload_from_authorization_header request
  person = Postoffice::Person.find(payload["id"])
  Postoffice::LoginService.reset_password person, data["password"]

  db_token = Postoffice::Token.new(value: token)
  db_token.mark_as_invalid

  [204, nil]

end

# View records for all people in the database.
# Filtering implemented, for example: /people?username=bigedubs
# Scope: admin
get '/people' do
  content_type :json
  if Postoffice::AppService.unauthorized?(request, "admin") then return [401, nil] end

  Postoffice::AppService.add_if_modified_since_to_request_parameters self
  response_body = Postoffice::PersonService.get_people(params).to_json( :except => ["salt", "hashed_password", "device_token"] )
  [200, response_body]

end

# Search people by username or name
# Scope: can-read
get '/people/search' do
  content_type :json
  if Postoffice::AppService.unauthorized?(request, "can-read") then return [401, nil] end

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
  data = JSON.parse request.body.read
  if Postoffice::AppService.unauthorized?(request, "can-read") then return [401, nil] end

  begin
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
  if Postoffice::AppService.not_admin_or_owner?(request, "can-write", params[:id]) then return [401, nil] end

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
  if Postoffice::AppService.not_admin_or_owner?(request, "can-write", params[:id]) then return [401, nil] end

  begin
    mail = Postoffice::MailService.create_mail params[:id], data
    mail.mail_it
    Postoffice::MailService.ensure_mail_arrives_in_order_it_was_sent mail
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
    if Postoffice::AppService.not_admin_or_mail_owner?(request, "can-read", mail) then return [401, nil] end

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
      [404, nil]
    else
      if Postoffice::AppService.not_admin_or_mail_owner?(request, "can-read", mail) then return [401, nil] end
      if params["thumb"]
        Postoffice::FileService.fetch_image(mail.image_uid, params).to_response
      else
        redirect Postoffice::FileService.get_presigned_url mail.image_uid
      end
    end
  rescue ArgumentError
    response_body = Hash["message", "Could not process thumbnail parameter."].to_json
    [403, nil, response_body]
  end

end

# Retrieve image for a piece of mail
# Scope: admin OR (can-read, is to or from person)
get '/mail/id/:id/thumbnail' do

  mail = Postoffice::Mail.find(params[:id])

  ## For legacy purposes, creating the thumbnail if it does not already exist
  if mail.thumbnail_uid == nil && mail.image_uid != nil
    mail.thumbnail = mail.image.thumb('x96')
    mail.save
  end

  if mail.thumbnail_uid == nil
    [404, nil, nil]
  else
    if Postoffice::AppService.not_admin_or_mail_owner?(request, "can-read", mail) then return [401, nil] end
    Postoffice::FileService.fetch_image(mail.thumbnail_uid).to_response
  end

end

# View all mail in the system
# Scope: admin
get '/mail' do
  content_type :json
  if Postoffice::AppService.unauthorized?(request, "admin") then return [401, nil] end
  Postoffice::AppService.add_if_modified_since_to_request_parameters self
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
    if Postoffice::AppService.not_admin_or_owner?(request, "can-write", from_id) then return [401, nil] end
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
post '/mail/id/:id/arrive_now' do

   begin
    mail = Postoffice::Mail.find(params[:id])
    from_id = Postoffice::Person.find_by(username: mail.from).id.to_s
    if Postoffice::AppService.not_admin_or_owner?(request, "can-write", from_id) then return [401, nil] end
    mail.make_it_arrive_now
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
    if Postoffice::AppService.not_admin_or_owner?(request, "can-write", to_id) then return [401, nil] end
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
  Postoffice::AppService.add_if_modified_since_to_request_parameters self
  if Postoffice::AppService.not_admin_or_owner?(request, "can-read", params[:id]) then return [401, nil] end

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
  Postoffice::AppService.add_if_modified_since_to_request_parameters self
  if Postoffice::AppService.not_admin_or_owner?(request, "can-read", params[:id]) then return [401, nil] end

  begin
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
  if Postoffice::AppService.not_admin_or_owner?(request, "can-read", params[:id]) then return [401, nil] end

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
  if Postoffice::AppService.unauthorized?(request, "can-write") then return [401, nil] end

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
  if Postoffice::AppService.unauthorized?(request, "can-read") then return [401, nil] end
  response_body = Postoffice::FileService.get_cards.to_json
  [200, response_body]
end

# Get a specific image
# Scope: can-read can get images in /resources only, admin can get any image
get '/image/*' do

  begin
    uid = params['splat'][0]
    if uid.include?("resources") == false && Postoffice::AppService.unauthorized?(request, "admin")
      return [401, nil]
    elsif Postoffice::AppService.unauthorized?(request, "can-read")
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

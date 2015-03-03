require_relative 'module/postoffice'

get '/' do
  "Hello World!"
end

post '/person/new' do

  data = JSON.parse request.body.read

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

  [201, headers, nil]

end

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

# To Do: Add searching, filtering
get '/people' do
  content_type :json
  response_body = SnailMail::Person.get_people(params).to_json
  [200, response_body]
end

post '/person/id/:id/mail/new' do
  begin
    person = SnailMail::Person.find_by(_id: params[:id])
    data = JSON.parse request.body.read

    mail = SnailMail::Mail.create!({
      from: person.username,
      to: data["to"],
      content: data["content"],
      status: "SENT",
      days_to_arrive: SnailMail::Mail.days_to_arrive
    })

    mail_link = "http://localhost:9292/mail/id/#{mail.id}"
    headers = { "location" => mail_link }
    status = 201
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    headers = nil
  end

  [status, headers, nil]

end

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

  # To Do: return response in parseable format
  [status, response_body]

end

get '/mail' do
  content_type :json
  response_body = SnailMail::Mail.get_mail(params).to_json
  [200, response_body]
end

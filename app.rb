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
  begin
    person = SnailMail::Person.find_by(_id: params[:id])
    status = 200
    response_body = person.as_document.as_json.to_s
  rescue Mongoid::Errors::DocumentNotFound
    status = 404
    response_body = nil
  end

  [status, response_body]
end

get '/people' do
  # @people = SnailMail::Person.all.to_a
end

post '/person/:id/mail/new' do
  @person = SnailMail::Person.find(params[:id])
  
  @message = SnailMail::Message.create!({
    id: SecureRandom.uuid,
    from: @person.username,
    to: params["to"],
    content: params["content"],
    status: "SENT"
  })
end

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

  status 201

end

post '/test' do

  person = SnailMail::Person.create!({
      username: "test",
      name: "Test",
      address1: "here",
      city: "there",
      state: "somewhere",
      zip: "00000"
    })

    status 201

end

get '/person/id/:id' do
  # @person = SnailMail::Person.find(params[:id])
  # @messages = SnailMail::Message.where(from: @person.id).to_a
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

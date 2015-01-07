require_relative 'module/postoffice'

get '/' do
end

post '/person/new' do
  content_type :json

  person = SnailMail::Person.create!({
    username: params["username"],
    name: params["name"],
    address1: params["address1"],
    city: params["city"],
    state: params["state"],
    zip: params["zip"]
  })
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

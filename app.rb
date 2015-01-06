require_relative 'module/posnail-office'

get '/' do
end

post '/user/new' do
  user = SnailMail::User.create!({
    username: params["username"],
    name: params["name"],
    address1: params["address1"],
    city: params["city"],
    state: params["state"],
    zip: params["zip"]
  })
end

get '/user/id/:id' do
  # @user = SnailMail::User.find(params[:id])
  # @messages = SnailMail::Message.where(from: @user.id).to_a
end

get '/users' do
  # @users = SnailMail::User.all.to_a
end

post '/user/:id/mail/new' do
  @user = SnailMail::User.find(params[:id])
  
  @message = SnailMail::Message.create!({
    id: SecureRandom.uuid,
    from: @user.id,
    to: params["to"],
    content: params["content"],
    status: "SENT"
  })
end

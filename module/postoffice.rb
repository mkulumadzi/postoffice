# load path
lib_path = File.expand_path('../', __FILE__)
($:.unshift lib_path) unless ($:.include? lib_path)

Bundler.require(:default)

# ENV['RACK_ENV'] = 'development'
Mongoid.load!('config/mongoid.yml')

Dir[File.dirname(__FILE__) + '/models/*.rb'].each do |file|
	require file
end

Dir[File.dirname(__FILE__) + '/services/*.rb'].each do |file|
	require file
end

##Configuring APNS for push notifications
## 2195 is the default port for Apple
APNS.host = 'gateway.sandbox.push.apple.com'

if ENV['RACK_ENV'] == 'staging' || ENV['RACK_ENV'] == 'production'
	APNS.pem  = 'certificates/snailtale_production.pem'
	APNS.host = 'gateway.push.apple.com'
else
	APNS.pem  = 'certificates/snailtale_development.pem'
	APNS.host = 'gateway.sandbox.push.apple.com'
end

APNS.port = 2195

## Configuring Dragonfly for accessing images
Dragonfly.app.configure do

	plugin :imagemagick

	secret 'I miss my Sony camera'

  datastore :s3,
    bucket_name: 'kuyenda-slowpost-development',
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY_ID']
end

## Configuring AWS for storign images
## To Do: Use Dragonfly for storing as well?
Aws.config.update({
  region: ENV['AWS_REGION'],
  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY_ID'])
})

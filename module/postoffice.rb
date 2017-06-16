# load path
lib_path = File.expand_path('../', __FILE__)
($:.unshift lib_path) unless ($:.include? lib_path)

Bundler.require(:default)

# ENV['RACK_ENV'] = 'development'
Mongoid.load!("config/mongoid.yml", ENV['RACK_ENV'])
Mongoid.logger.level = Logger::INFO
Mongo::Logger.logger.level = Logger::INFO

Dir[File.dirname(__FILE__) + '/models/*.rb'].each do |file|
	require file
end

Dir[File.dirname(__FILE__) + '/services/*.rb'].each do |file|
	require file
end

## Configuring AWS for storing images
## To Do: Use Dragonfly for storing as well?
Aws.config.update({
  region: 'us-west-2',
  credentials: Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'], ENV['AWS_SECRET_ACCESS_KEY'])
})

# Method for getting certificate files if necessary
def get_certificate_file_from_aws_if_neccessary filename, directory
	if !File.exists?(filename) || File.zero?(filename)
		s3 = Aws::S3::Resource.new
		bucket = s3.bucket('kuyenda-slowpost-certificates')
		cert = bucket.object(filename)
		temp_cert_file = File.new("#{directory}/#{filename}", 'w')
		cert.get({response_target: temp_cert_file})
	end
end

##Configuring APNS for push notifications
## 2195 is the default port for Apple
APNS.host = 'gateway.sandbox.push.apple.com'

if ENV['RACK_ENV'] == 'staging' || ENV['RACK_ENV'] == 'production'
	get_certificate_file_from_aws_if_neccessary 'slowpost_production.pem', 'certificates'
	APNS.pem  = 'certificates/slowpost_production.pem'
	APNS.host = 'gateway.push.apple.com'
else
	get_certificate_file_from_aws_if_neccessary 'slowpost_development.pem', 'certificates'
	APNS.pem  = 'certificates/slowpost_development.pem'
	APNS.host = 'gateway.sandbox.push.apple.com'
end

APNS.port = 2195

## Configuring Dragonfly for accessing images
Dragonfly.app.configure do

	plugin :imagemagick

	secret 'I miss my Sony camera'

  datastore :s3,
		region: 'us-west-2',
    bucket_name: ENV['AWS_BUCKET'],
    access_key_id: ENV['AWS_ACCESS_KEY_ID'],
    secret_access_key: ENV['AWS_SECRET_ACCESS_KEY']
end

## Increasing max keyspace limit to allow photo uploads in base64 format...
if Rack::Utils.respond_to?("key_space_limit=")
  Rack::Utils.key_space_limit = 1048576 # 16 times the default size
end

## Configuring permissions for cross-origin requests
configure do
  enable :cross_origin
	set :allow_origin, :any
	set :allow_methods, [:get, :post, :options]
	set :allow_credentials, true
	set :max_age, "1728000"
	set :expose_headers, ['Content-Type']
end

## Configuring Postmark for sending emails

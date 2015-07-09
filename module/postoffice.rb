# load path
lib_path = File.expand_path('../', __FILE__)
($:.unshift lib_path) unless ($:.include? lib_path)

Bundler.require(:default)

ENV['RACK_ENV'] = 'development'
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

if ENV['RACK_ENV'] == 'development'
	APNS.pem  = 'certificates/snailtale_development.pem'
elsif ENV['RACK_ENV'] == 'staging'
	APNS.pem  = 'certificates/snailtale_production.pem'
elsif ENV['RACK_ENV'] == 'production'
	APNS.pem = 'certificates/snailtale_production.pem'
end

APNS.port = 2195
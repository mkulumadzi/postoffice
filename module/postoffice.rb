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
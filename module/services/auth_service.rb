require 'jwt'

module Postoffice

	class AuthService

		def self.get_private_key
			pem = File.read 'certificates/private_key.pem'
			key = OpenSSL::PKey::RSA.new pem, ENV['POSTOFFICE_KEYWORD']
			key
		end

		def self.get_public_key
			pem = File.read 'certificates/public_key.pem'
			OpenSSL::PKey::RSA.new pem
		end

		def self.generate_expiration_date_for_token
			#Generate a date that is 3 months in the future
			Time.now.to_i + 3600 * 24 * 72
		end

		def self.generate_payload_for_person person
			exp = self.generate_expiration_date_for_token
			{:id => person.id.to_s, :exp => exp}
		end

		def self.generate_token_for_person person
			payload = self.generate_payload_for_person person
			rsa_private = self.get_private_key
			token = JWT.encode payload, rsa_private, 'RS256'
			token
		end

	end

end

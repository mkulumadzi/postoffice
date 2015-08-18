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
      scope = self.get_scopes_for_user_type "person"
			{:id => person.id.to_s, :exp => exp, :scope => scope}
		end

		def self.generate_token_for_person person
			payload = self.generate_payload_for_person person
      token = self.generate_token payload
			token
		end

    def self.generate_token payload
      rsa_private = self.get_private_key
      token = JWT.encode payload, rsa_private, 'RS256'
    end

    def self.get_scopes_for_user_type user_type
      case user_type
      when "person"
        "can-read can-write"
      when "app"
        "create-person reset-password"
      when "admin"
        "admin can-read can-write create-person reset-password bulk-search can-upload get-image"
      else
        nil
      end
    end

    def self.generate_payload_for_user_type user_type
      raise "Unrecognized user type" unless user_type == "app" || user_type == "admin"
      scope = self.get_scopes_for_user_type user_type
      payload = {:scope => scope }
    end

    def self.get_admin_token
      payload = self.generate_payload_for_user_type "admin"
      self.generate_token payload
    end

    def self.get_app_token
      payload = self.generate_payload_for_user_type "app"
      self.generate_token payload
    end

    def self.decode_token token
      public_key = Postoffice::AuthService.get_public_key
      decoded_token = JWT.decode token, public_key
      decoded_token
    end

	end

end

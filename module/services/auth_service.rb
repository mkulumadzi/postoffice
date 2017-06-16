require 'jwt'

module Postoffice

	class AuthService

		def self.get_private_key
			get_certificate_file_from_aws_if_neccessary 'private_key.pem', 'certificates'
			f = File.open('certificates/private_key.pem', 'r')
			pem = f.read
			f.close
			OpenSSL::PKey::RSA.new pem, ENV['POSTOFFICE_KEYWORD']
		end

		def self.get_public_key
			get_certificate_file_from_aws_if_neccessary 'public_key.pem', 'certificates'
			f = File.open('certificates/public_key.pem', 'r')
			pem = f.read
			f.close
			OpenSSL::PKey::RSA.new pem
		end

		def self.generate_expiration_date_for_token
			#Generate a date that is 3 months in the future
			Time.now.to_i + 3600 * 24 * 72
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
			payload = {:scope => scope}
		end

		def self.generate_payload_for_person person
			exp = self.generate_expiration_date_for_token
			scope = self.get_scopes_for_user_type "person"
			{:id => person.id.to_s, :exp => exp, :scope => scope}
		end

		def self.send_password_reset_email person, api_key = "POSTMARK_API_TEST"
			token = self.get_password_reset_token person
			email_hash = self.get_password_reset_email_hash person, token
			Postoffice::EmailService.send_email email_hash, api_key
		end

		def self.get_password_reset_token person
			payload = self.generate_payload_for_password_reset person
			token = self.generate_token payload
		end

		def self.generate_payload_for_password_reset person
			exp = Time.now.to_i + 3600 * 24
			{:id => person.id.to_s, :exp => exp, :scope => "reset-password"}
		end

		def self.get_password_reset_email_hash person, token
			banner_image_attachment = Postoffice::EmailService.image_email_attachment("resources/slowpost_banner.png")
			template = 'resources/password_reset_email_template.html'
			variables = Hash(person: person, token: token)

			Hash[
				from: ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"],
				to: person.email,
				subject: "We received a request to reset your password",
				html_body: Postoffice::EmailService.generate_email_message_body(template, variables),
				track_opens: true,
				attachments: [banner_image_attachment]
			]
		end

		def self.send_email_validation_email_if_necessary person, api_key = "POSTMARK_API_TEST"
			if person.email_address_validated == true
				nil
			else
				token = self.get_email_validation_token person
				email_hash = self.get_email_validation_hash person, token
				Postoffice::EmailService.send_email email_hash, api_key
			end
		end

		def self.get_email_validation_token person
			payload = self.generate_payload_for_email_validation person
			token = self.generate_token payload
		end

		def self.generate_payload_for_email_validation person
			exp = Time.now.to_i + 3600 * 24
			{:id => person.id.to_s, :exp => exp, :scope => "validate-email"}
		end

		def self.get_email_validation_hash person, token
			banner_image_attachment = Postoffice::EmailService.image_email_attachment("resources/slowpost_banner.png")
			template = 'resources/validate_email_template.html'
			variables = Hash(person: person, token: token)

			Hash[
				from: ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"],
				to: person.email,
				subject: "Please validate your email address",
				html_body: Postoffice::EmailService.generate_email_message_body(template, variables),
				track_opens: true,
				attachments: [banner_image_attachment]
			]
		end

		def self.generate_token payload
			rsa_private = self.get_private_key
			token = JWT.encode payload, rsa_private, 'RS256'
		end

		def self.get_admin_token
			payload = self.generate_payload_for_user_type "admin"
			payload[:exp] = Time.now.to_i + 3600
			self.generate_token payload
		end

		def self.get_app_token
			payload = self.generate_payload_for_user_type "app"
			self.generate_token payload
		end

		def self.get_test_token
			exp = Time.now.to_i + 60
			payload = Hash(scope: "test", exp: exp)
			self.generate_token payload
		end

		def self.generate_token_for_person person
			payload = self.generate_payload_for_person person
      token = self.generate_token payload
			token
		end

    def self.decode_token token
      public_key = Postoffice::AuthService.get_public_key
      decoded_token = JWT.decode token, public_key
      decoded_token
    end

		def self.token_is_invalid token
			begin
				db_token = Postoffice::Token.find_by(value: token)
				if db_token.is_invalid
					true
				else
					false
				end
			rescue Mongoid::Errors::DocumentNotFound
				false
			end
		end

	end

end

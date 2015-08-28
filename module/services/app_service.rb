module Postoffice

  class AppService
    # Convenience Methods
    def self.add_if_modified_since_to_request_parameters app
      if app.request.env["HTTP_IF_MODIFIED_SINCE"]
        utc_date = Time.parse(app.request.env["HTTP_IF_MODIFIED_SINCE"])
        app.params[:updated_at] = { "$gt" => utc_date }
      end
    end

    def self.get_token_from_authorization_header request
      token_header = request.env["HTTP_AUTHORIZATION"]
      token_header.split(' ')[1]
    end

    def self.get_payload_from_authorization_header request
      if request.env["HTTP_AUTHORIZATION"] != nil
        begin
          token = self.get_token_from_authorization_header request
          decoded_token = Postoffice::AuthService.decode_token token
          payload = decoded_token[0]
        rescue JWT::ExpiredSignature
          "Token expired"
        rescue JWT::VerificationError
          "Invalid token signature"
        rescue JWT::DecodeError
          "Token is invalid"
        end
      else
        "No token provided"
      end
    end

    def self.unauthorized? request, required_scope
      payload = self.get_payload_from_authorization_header request
      if payload["scope"] == nil
        true
      elsif payload["scope"].include? required_scope
        false
      else
        true
      end
    end

    def self.not_authorized_owner? request, required_scope, person_id
      payload = self.get_payload_from_authorization_header request
      id = payload["id"]

      if payload["scope"] == nil
        true
      elsif payload["scope"].include?(required_scope) && id == person_id
        false
      else
        true
      end
    end

    def self.not_admin_or_owner? request, scope, person_id
      if self.unauthorized?(request, "admin") && self.not_authorized_owner?(request, scope, person_id)
        true
      else
        false
      end
    end

    def self.not_admin_or_mail_owner? request, scope, mail
      from_id = Postoffice::Person.find_by(username: mail.from).id.to_s
      to_id = Postoffice::Person.find_by(username: mail.to).id.to_s
      if self.unauthorized?(request, "admin") && self.not_authorized_owner?(request, scope, from_id) && self.not_authorized_owner?(request, scope, to_id)
        true
      else
        false
      end
    end

    def self.get_api_version_from_content_type request
      content_type = request.env["CONTENT_TYPE"]
      if content_type && content_type.include?("application/vnd.postoffice")
        version = content_type.split('.').last.split('+')[0]
      else
        version = "v1"
      end
      version
    end
  end

end

module Postoffice

  class AppService
    # Convenience Methods
    def self.add_if_modified_since_to_request_parameters app
      if app.request.env["HTTP_IF_MODIFIED_SINCE"]
        utc_date = Time.parse(app.request.env["HTTP_IF_MODIFIED_SINCE"])
        app.params[:updated_at] = { "$gt" => utc_date }
      end
    end

    def self.add_if_modified_since_to_request_as_date app
      if app.request.env["HTTP_IF_MODIFIED_SINCE"]
        utc_date = Time.parse(app.request.env["HTTP_IF_MODIFIED_SINCE"])
        app.params[:updated_at] = utc_date
      end
    end

    def self.get_token_from_authorization_header request
      token_header = request.env["HTTP_AUTHORIZATION"]
      if token_header
        token_header.split(' ')[1]
      else
        nil
      end
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
      token = self.get_token_from_authorization_header request
      if Postoffice::AuthService.token_is_invalid(token)
        true
      elsif payload["scope"] == nil
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
      token = self.get_token_from_authorization_header request

      if Postoffice::AuthService.token_is_invalid(token)
        true
      elsif payload["scope"] == nil
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
      correspondent_ids = mail.people_correspondent_ids
      payload = self.get_payload_from_authorization_header request
      if payload["id"] then person_id = BSON::ObjectId(payload["id"]) end
      if self.unauthorized?(request, "admin") == false
        false
      elsif correspondent_ids.include?(person_id) && self.unauthorized?(request, scope) == false
        false
      else
        true
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

    def self.add_updated_since_to_query query, params
      if params[:updated_at] then query = query.where(updated_at: params[:updated_at]) end
      query
    end

    def self.convert_objects_to_documents array
      document_array = []
      array.each { |e| document_array << e.as_document }
      document_array
    end

    def self.create_json_of_mail_for_person mail_array, person
      hash_array = []
      mail_array.each { |mail| hash_array << Postoffice::MailService.hash_of_mail_for_person(mail, person) }
      hash_array.to_json
    end

    def self.single_mail_response request, mail
      payload = self.get_payload_from_authorization_header request
      if payload["scope"].include?("admin")
        mail.as_document.to_json
      elsif payload["id"]
        person = Postoffice::Person.find(payload["id"])
        Postoffice::MailService.hash_of_mail_for_person(mail, person).to_json
      end
    end

    def self.email_api_key request
      if request.params["test"] == "true"
        "POSTMARK_API_TEST"
      else
        ENV["POSTMARK_API_KEY"]
      end
    end

  end

end

require 'erb'

module Postoffice

  class EmailService

    def self.image_email_attachment filename
      Hash[
        "Name" => filename,
        "Content" => Postoffice::FileService.encode_file(filename),
        "ContentType" => Postoffice::FileService.image_content_type(filename),
        "ContentID" => "cid:#{filename}"
      ]
    end

    def self.generate_email_message_body template, hash
      temp_filename = self.temp_filename
      self.create_temp_file_and_render_template temp_filename, template, hash
      message_body = Premailer.new(temp_filename, :warn_level => Premailer::Warnings::SAFE).to_inline_css
      File.delete(temp_filename)
      message_body
    end

    def self.temp_filename
      id =  SecureRandom.hex
      "tmp/#{id}.html"
    end

    def self.create_temp_file_and_render_template temp_filename, template, hash
      temp_file = File.open(temp_filename, 'w')
      temp_file.write(self.render_template(template, hash))
      temp_file.close
    end

    def self.render_template template, hash
      file = File.open(template)
      contents = file.read
      file.close
      ERB.new(contents).result(binding)
    end

    def self.send_email email, email_api_key = "POSTMARK_API_TEST"
      client = Postmark::ApiClient.new(email_api_key)
      client.deliver(email)
    end

  end

end

module SnailMail

	class FileService

    def self.create_key
      SecureRandom.uuid()
    end

    def self.get_object_for_key key
      s3 = Aws::S3::Resource.new
      s3.bucket(ENV['AWS_BUCKET']).object(key)
    end

    def self.decode_string_to_file base64_string, key
      file = File.open("tmp/#{key}", 'wb')
      file.write(Base64.decode64(base64_string))
      file.close
      file
    end

    def self.encode_file_contents file_contents
      Base64.encode64(file_contents)
    end

    def self.put_file base64_string
      key = self.create_key
      obj = self.get_object_for_key key
      file = File.open(self.decode_string_to_file base64_string, key)
      obj.put(body: file)
      file.close
      key
    end

    def self.delete_temporary_file filename
      unless File.exists?('tmp/' + filename)
        raise "File not found."
      end

      File.delete('tmp/' + filename)
    end

	end

end

module SnailMail

	class FileService

    def self.create_key_for_filename filename
      ext = self.get_extension_from_filename filename
      uuid = SecureRandom.uuid()
      uuid + ext
    end

    def self.get_extension_from_filename filename
      unless filename
        raise "Filename must be included in request"
      end

      if filename.include? '.'
        split_file = filename.split('.')
        file_extension = split_file[split_file.length - 1]
        "." + file_extension
      else
        nil
      end
    end

    def self.get_object_for_key key
      s3 = Aws::S3::Resource.new
      s3.bucket(ENV['AWS_BUCKET']).object(key)
    end

    def self.put_file file, filename
      key = self.create_key_for_filename filename
      obj = self.get_object_for_key key
      obj.put(body: file)
      key
    end

	end

end

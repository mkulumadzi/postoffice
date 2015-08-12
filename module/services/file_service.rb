module Postoffice

	class FileService

    def self.decode_string_to_file base64_string, key
      file = File.open("tmp/#{key}", 'wb')
      file.write(Base64.decode64(base64_string))
      file.close
      file
    end

    def self.upload_file data
      file = File.open(self.decode_string_to_file data["file"], data["filename"])
      uid = Dragonfly.app.store(file.read, 'name' => data["filename"])
      file.close
      File.delete(file)
      uid
    end

		def self.fetch_image image_uid, params
			if params["thumb"]
				Dragonfly.app.fetch(image_uid).thumb(params["thumb"])
			else
				Dragonfly.app.fetch(image_uid)
			end
		end

		def self.get_cards
			s3 = Aws::S3::Resource.new
	    bucket = s3.bucket(ENV['AWS_BUCKET'])
	    cards = bucket.objects(prefix: 'resources/cards').collect(&:key)
			cards.delete('resources/cards/')
			cards
		end

	end

end

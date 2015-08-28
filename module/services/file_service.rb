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

		def self.fetch_image image_uid, params = Hash.new
			if params["thumb"]
				Dragonfly.app.fetch(image_uid).thumb(params["thumb"])
			else
				Dragonfly.app.fetch(image_uid)
			end
		end

		def self.get_bucket
			s3 = Aws::S3::Resource.new
			s3.bucket(ENV['AWS_BUCKET'])
		end

		def self.get_cards
			bucket = self.get_bucket
			cards = bucket.objects(prefix: 'resources/cards').collect(&:key)
			cards.delete('resources/cards/')
			cards
		end

		## Might not need this, if Cloudfront can do the trick...
		# def self.get_presigner
		# 	Aws::S3::Presigner.new
		# end
		#
		# def self.get_object key
		# 	bucket = self.get_bucket
		# 	Aws::S3::Object bucket, key
		# end
		#
		# def self.add_thumb key, thumb
		# 	key_split = key.split('.')
		# 	extension = key_split.pop
		# 	key_split.join("") + "_" + thumb + extension
		# end
		#
		# def self.thumbnail_exists? key, thumb
		# 	key = self.add_thumb key, thumb
		# 	object = self.get_object key
		# 	object.exists?
		# end
		#
		# def self.create_thumbnail_version_if_necessary key, thumb
		# 	if !(self.thumbnail_exists? key, thumb)
		# 		self.create_thumbnail key, thumb
		# 	end
		# end
		#
		# def self.fetch_image_with_thumb key, thumb
		# 	Dragonfly.app.fetch(key).thumb(thumb)
		# end
		#
		# def self.create_thumbnail key, thumb
		#
		# end
		#
		# def self.get_presigned_url key
		# 	presigner = self.get_presigner
		# 	presigner.presigned_url(:get_object, bucket: ENV['AWS_BUCKET'], key: key, expires_in: 60)
		# end
		#
		# def self.get_presigned_url_for_object_and_create_thumbnail_version_if_necessary key, thumb = nil
		# 	if thumb then self.create_thumbnail_version_if_necessary key, thumb end
		# 	if thumb then key = self.add_thumb key, thumb end
		# 	self.get_presigned_url key
		# end

	end

end

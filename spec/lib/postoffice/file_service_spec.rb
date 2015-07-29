require_relative '../../spec_helper'

describe SnailMail::FileService do

  describe 'get extension from filename' do

    it 'must return the extension for a file' do
      filename = "image.jpg"
      ext = SnailMail::FileService.get_extension_from_filename filename
      ext.must_equal ".jpg"
    end

    it 'must return an extension even for files that have multiple periods in the name' do
      filename = "kuyenda.image.png"
      ext = SnailMail::FileService.get_extension_from_filename filename
      ext.must_equal ".png"
    end

    it 'must return nil if there is no extension' do
      filename = "kuyenda"
      ext = SnailMail::FileService.get_extension_from_filename filename
      ext.must_equal nil
    end

    it 'must raise an argument error if the filename is nil' do
      filename = nil
      assert_raises RuntimeError do
        SnailMail::FileService.get_extension_from_filename filename
      end
    end

  end

  describe 'create key for filename' do

    before do
      filename = "image.jpg"
      key = SnailMail::FileService.create_key_for_filename filename
      @split_key = key.split('.')
    end

    it 'must prepend the key with a 36-character uuid' do
      uuid = @split_key[0]
      assert_match /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/, uuid
    end

    it 'must append the key with the file extension' do
      ext = @split_key[1]
      ext.must_equal "jpg"
    end

  end

  describe 'get AWS s3 for key' do

    before do
      @obj = SnailMail::FileService.get_object_for_key "abc"
    end

    it 'must create an AWS S3 for the key' do
      @obj.must_be_instance_of Aws::S3::Object
    end

    it 'must store the key for this object' do
      @obj.key.must_equal "abc"
    end

    it 'must use the bucket stored in the AWS_BUCKET environment variable' do
      @obj.bucket_name.must_equal ENV['AWS_BUCKET']
    end

  end

  describe 'put file' do

    before do
      file = File.open('resources/image1.jpg')
      filename = 'image1.jpg'
      @key = SnailMail::FileService.put_file file, filename
    end

    it 'must return a key that is a UUID plus the file extension' do
      assert_match /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}.jpg/, @key
    end

    it 'must upload the file to the AWS S3 store' do
      s3 = Aws::S3::Resource.new
      obj = s3.bucket(ENV['AWS_BUCKET']).object(@key)
      obj.exists?.must_equal true
    end

  end


end

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

    it 'must raise a runtime error if the filename is nil' do
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

  describe 'encode a file as a Base64 string' do

    before do
      @file = File.open('resources/asamplefile.txt')
      @file_contents = @file.read
    end

    after do
      @file.close
    end

    it 'must encode the contents of the file as a Base64 string' do
      base64 = SnailMail::FileService.encode_file_contents(@file_contents)
      base64.must_equal Base64.encode64(@file_contents)
    end

  end

  describe 'decode a base64 string and return a file' do

    before do
      @string = "This is a string to encode."
      base64_string = Base64.encode64(@string)
      @filename = "sample.txt"
      @file = File.open(SnailMail::FileService.decode_string_to_file base64_string, @filename)
      @file_contents = @file.read
    end

    after do
      @file.close
    end

    it 'must decode the string and store it in the file' do
      @file_contents.must_equal @string
    end

    it 'must store the name of the file' do
      File.basename(@file).must_equal @filename
    end

  end

  describe 'put file' do

    before do
      base64_string = Base64.encode64("I am uploading this file.")
      filename = "Uploaded.txt"
      @key = SnailMail::FileService.put_file base64_string, filename
    end

    it 'must return a key that is a UUID plus the file extension' do
      assert_match /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}.txt/, @key
    end

    it 'must upload the file to the AWS S3 store' do
      s3 = Aws::S3::Resource.new
      obj = s3.bucket(ENV['AWS_BUCKET']).object(@key)
      obj.exists?.must_equal true
    end

  end


end

require_relative '../../spec_helper'

describe SnailMail::FileService do

  describe 'create key' do

    before do
      @key = SnailMail::FileService.create_key
    end

    it 'must generate a uuid' do
      assert_match /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/, @key
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
      @file = File.open('spec/resources/asamplefile.txt')
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
      @key = "samplekey"
      @file = File.open(SnailMail::FileService.decode_string_to_file base64_string, @key)
      @file_contents = @file.read
    end

    after do
      @file.close
      File.delete(@file)
    end

    it 'must decode the string and store it in the file' do
      @file_contents.must_equal @string
    end

    it 'must store the key as the name of the file' do
      File.basename(@file).must_equal @key
    end

  end

  describe 'delete temporary file' do

    it 'must delete a file if it exists in the /tmp directory' do
      file = File.open('tmp/filetodelete.txt', 'w')
      file.close
      SnailMail::FileService.delete_temporary_file 'filetodelete.txt'
      File.exists?('tmp/filetodelete.txt').must_equal false
    end

    it 'must raise a RuntimeError if the file is not found' do
      assert_raises RuntimeError do
        SnailMail::FileService.delete_temporary_file 'thisoneisnotthere.txt'
      end
    end

  end

  describe 'put file' do

    before do
      base64_string = Base64.encode64("I am uploading this file.")
      @key = SnailMail::FileService.put_file base64_string
    end

    after do
      SnailMail::FileService.delete_temporary_file @key
    end

    it 'must return a UUID as the key' do
      assert_match /[0-9a-f]{8}-([0-9a-f]{4}-){3}[0-9a-f]{12}/, @key
    end

    it 'must upload the file to the AWS S3 store' do
      s3 = Aws::S3::Resource.new
      obj = s3.bucket(ENV['AWS_BUCKET']).object(@key)
      obj.exists?.must_equal true
    end

  end


end

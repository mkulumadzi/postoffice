require_relative '../../spec_helper'

describe SnailMail::FileService do

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

  describe 'upload file using Dragonfly' do

    before do
      @contents = "I am uploading this file."
      base64_string = Base64.encode64(@contents)
      @filename = "sample.txt"
      data = JSON.parse(('{"file": "'+ base64_string + '", "filename": "' + @filename + '"}').gsub("\n", ""))
      @uid = SnailMail::FileService.upload_file data
    end

    it 'must return a String as the UID' do
      @uid.must_be_instance_of String
    end

    it 'must upload the file to the AWS S3 store' do
      contents = Dragonfly.app.fetch(@uid).data
      contents.must_equal @contents
    end

    it 'must store the filename' do
      Dragonfly.app.fetch(@uid).name.must_equal @filename
    end

    it 'must delete the temporary file' do
      File.exists?('tmp/' + @filename).must_equal false
    end

  end

  describe 'fetch image' do

    before do
      @image = File.open('spec/resources/image2.jpg')
      @uid = Dragonfly.app.store(@image.read, 'name' => 'image2.jpg')
    end

    after do
      @image.close
    end

    describe 'fetch full image' do

      before do
        params = ""
        @image_fetched = SnailMail::FileService.fetch_image @uid, params
      end

      it 'must fetch the image' do
        @image_fetched.name.must_equal 'image2.jpg'
      end

      it 'must fetch the full image' do
        @image_fetched.size.must_equal @image.size
      end

    end

    describe 'fetch image with thumbnail' do

      it 'must resize the image if a thumbnail is given' do
        params = Hash["thumb", "400x"]
        image_fetched = SnailMail::FileService.fetch_image @uid, params
        image_fetched.width.must_equal 400
      end

      it 'must return a Argument Error if the thumbnail parameter is invalid' do
        params = Hash["thumb", "splat"]
        assert_raises ArgumentError do
          image_fetched = SnailMail::FileService.fetch_image @uid, params
          image_fetched.apply
        end
      end

    end

  end

end

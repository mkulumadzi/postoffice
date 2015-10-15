require_relative '../../spec_helper'

describe Postoffice::EmailService do

  describe 'image email attachment' do

    before do
      @filename = 'resources/slowpost_banner.png'
      @image_attachment = Postoffice::EmailService.image_email_attachment @filename
    end

    it 'must return a Hash' do
      @image_attachment.must_be_instance_of Hash
    end

    it 'must point Name to the filename' do
      @image_attachment["Name"].must_equal @filename
    end

    it 'must include the base64-encoded content for the file' do
      @image_attachment["Content"].must_equal Postoffice::FileService.encode_file(@filename)
    end

    it 'must include the content type' do
      @image_attachment["ContentType"].must_equal "image/png"
    end

    it 'must have prepended the filename with cid: for the ContentId' do
      @image_attachment["ContentID"].must_equal "cid:#{@filename}"
    end

  end

  describe 'generate the email message body' do

    before do
      @person = create(:person, username: random_username, email: "test@test.com")
      @hash = Hash(person: @person)
      @temp_filename = Postoffice::EmailService.temp_filename
      @template = 'resources/test_email_template.html'
    end

    describe 'temp filename' do

      it 'must prepend tmp/' do
        split = @temp_filename.split('/')
        split[0].must_equal 'tmp'
      end

      it 'must append .html' do
        split = @temp_filename.split('.')
        split[1].must_equal 'html'
      end

      it 'must generate a 32 character securerandom hex for the filename' do
        split1 = @temp_filename.split('/')
        split2 = split1[1].split('.')
        split2[0].length.must_equal 32
      end

    end

    describe 'create temp file and render template' do

      before do
        Postoffice::EmailService.create_temp_file_and_render_template @temp_filename, @template, @hash
      end

      after do
        File.delete(@temp_filename)
      end

      describe 'render template' do

        before do
          @rendered_template = Postoffice::EmailService.render_template @template, @hash
        end

        it 'must return an HTML string' do
          @rendered_template.include?("<head>").must_equal true
        end

        it 'must have rendered the template using ERB and added the necessary variables' do
          @rendered_template.include?("test@test.com").must_equal true
        end

      end

      it 'must have created a temporary file' do
        File.exist?(@temp_filename).must_equal true
      end

      it 'must have saved the rendered content of the email template to this file' do
        file = File.open(@temp_filename)
        contents = file.read
        file.close
        contents.must_equal Postoffice::EmailService.render_template @template, @hash
      end

    end

    describe 'generate message' do

      before do
        @message_body = Postoffice::EmailService.generate_email_message_body @template, @hash
      end

      it 'must return a string' do
        @message_body.must_be_instance_of String
      end

      it 'must have added inline css to the template' do
        @message_body.include?("style=").must_equal true
      end

      it 'must haave deleted the temporary file' do
        File.exists?(@temp_filename).must_equal false
      end

    end

  end

  describe 'send email' do

    before do
      @email_hash = Hash[from: "postman@slowpost.me", to: "evan@slowpost.me", subject: "This is a test", html_body: "<strong>Hello</strong> Evan!", track_opens: false]
      @result = Postoffice::EmailService.send_email @email_hash
    end

    it 'must not get an error' do
      @result[:error_code].must_equal 0
    end

    it 'must be sent to the right person' do
      @result[:to].must_equal @email_hash[:to]
    end

    it 'must have a unique id' do
      @result[:message_id].must_be_instance_of String
    end

    it 'must indicate that the test job was accepted' do
      @result[:message].must_equal "Test job accepted"
    end

  end

end

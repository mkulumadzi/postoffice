require_relative '../../spec_helper'

describe Postoffice::Attachment do

  describe 'create an attachment' do

    before do
			@mail1 = create(:mail)
      @attachment = Postoffice::Attachment.new
      @mail1.attachments << @attachment
    end

    it 'must have an object id' do
      @attachment.id.must_be_instance_of BSON::ObjectId
    end

    it 'must indicate the time it was created' do
      @attachment.created_at.must_be_instance_of Time
    end

    it 'must indicate the time it was updated' do
      @attachment.updated_at.must_be_instance_of Time
    end

    it 'must be able to be retrieved from the mail' do
      @mail1.attachments.include?(@attachment).must_equal true
    end

		it 'must be able to retrieve its parent mail' do
			@attachment.mail.must_equal @mail1
		end

  end

  describe Postoffice::Note do

    before do
      @note = build(:note)
    end

    it 'must store the content' do
      @note.content.must_be_instance_of String
    end

    it 'must indicate its type is Postoffice::Note' do
      @note._type.must_equal "Postoffice::Note"
    end

  end

  describe Postoffice::ImageAttachment do

    before do
      image = File.open('spec/resources/image2.jpg')
      @uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
      image.close

      @image_attachment = build(:image_attachment, image_uid: @uid)
    end

    it 'must indicate its type is Postoffice::ImageAttachment' do
      @image_attachment._type.must_equal "Postoffice::ImageAttachment"
    end

    it 'must store the uid' do
      @image_attachment.image_uid.must_equal @uid
    end

    it 'must have an image accessor that can be used to fetch the dragonfly image attributes, such as size' do
      @image_attachment.image.size.must_be_instance_of Fixnum
    end

    describe 'url' do

      it 'must generate a url for the image using the base url' do
        @image_attachment.url.must_equal "#{ENV['POSTOFFICE_BASE_URL']}/image/#{@image_attachment.image_uid}"
      end

    end

  end

end

require_relative '../../spec_helper'

describe Postoffice::Contact do

	Mongoid.load!('config/mongoid.yml')

	before do
		@person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)

    @contact1 = create(:contact, person_id: @person1.id, contact_person_id: @person2.id)

    @expected_attrs = attributes_for(:contact)
	end

	describe 'create a contact' do

		describe 'store the fields' do

      it 'must have an id' do
        @contact1.id.must_be_instance_of BSON::ObjectId
      end

			it 'must store the person_id' do
				@contact1.person_id.must_equal @person1.id.to_s
			end

      it 'must store the contact_person_id' do
        @contact1.contact_person_id.must_equal @person2.id.to_s
      end

      it 'must indicate whether the contact is a penpal' do
        @contact1.is_penpal.must_equal @expected_attrs[:is_penpal]
      end

      it 'must indicate whether the contact is in the address book' do
        @contact1.in_address_book.must_equal @expected_attrs[:in_address_book]
      end

      it 'must indicate when the record was created' do
        @contact1.created_at.must_be_instance_of Time
      end

      it 'must indicate when the record was updated' do
        @contact1.updated_at.must_be_instance_of Time
      end

      it 'must have a unique index for person_id and contact_person_id' do
        assert_raises Moped::Errors::OperationFailure do
          create(:contact, person_id: @person1.id, contact_person_id: @person2.id)
        end
      end

		end

	end

end

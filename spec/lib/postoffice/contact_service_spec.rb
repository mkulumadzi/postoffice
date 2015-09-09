require_relative '../../spec_helper'

describe Postoffice::ContactService do

  before do
    @person1 = create(:person, username: random_username)
    @person2 = create(:person, username: random_username)
    @person3 = create(:person, username: random_username)

    @contact1 = create(:contact, person_id: @person1.id, contact_person_id: @person2.id)

    @expected_attrs = attributes_for(:contact)
  end

  describe 'get contact' do

    it 'must return a contact if one is found' do
      contact = Postoffice::ContactService.get_contact @person1, @person2
      contact.must_be_instance_of Postoffice::Contact
    end

    it 'must return nil if no contact exists' do
      contact = Postoffice::ContactService.get_contact @person1, @person3
      contact.must_equal nil
    end

  end

  describe 'create penpal contact' do

    before do
      @contact = Postoffice::ContactService.add_penpal_contact @person1, @person3
    end

    it 'must create the contact' do
      @contact.must_be_instance_of Postoffice::Contact
    end

    it 'must set the person_id' do
      @contact.person_id.must_equal @person1.id.to_s
    end

    it 'must set the contact_person_id' do
      @contact.contact_person_id.must_equal @person3.id.to_s
    end

    it 'must set is_penpal to true' do
      @contact.is_penpal.must_equal true
    end

    it 'must set in_address_book to false' do
      @contact.in_address_book.must_equal false
    end

  end

  describe 'create address book contact' do

    before do
      @contact = Postoffice::ContactService.add_address_book_contact @person1, @person3
    end

    it 'must create the contact' do
      @contact.must_be_instance_of Postoffice::Contact
    end

    it 'must set the person_id' do
      @contact.person_id.must_equal @person1.id.to_s
    end

    it 'must set the contact_person_id' do
      @contact.contact_person_id.must_equal @person3.id.to_s
    end

    it 'must set is_penpal to false' do
      @contact.is_penpal.must_equal false
    end

    it 'must set in_address_book to true' do
      @contact.in_address_book.must_equal true
    end

  end

  describe 'add or update penpal contact' do

    it 'must create a new contact record if none exists' do
      contact = Postoffice::ContactService.add_or_update_penpal_contact @person1, @person3
      contact.must_be_instance_of Postoffice::Contact
    end

    it 'must update an existing contact record if none exists' do
      Postoffice::ContactService.add_address_book_contact @person1, @person3
      contact = Postoffice::ContactService.add_or_update_penpal_contact @person1, @person3
      contact.is_penpal.must_equal true
    end

    it 'must not update the contact if it is already a penpal' do
      Postoffice::ContactService.add_penpal_contact @person1, @person3
      contact = Postoffice::ContactService.add_or_update_penpal_contact @person1, @person3
      contact.must_equal nil
    end

  end

  describe 'add or update address book contact' do

    it 'must create a new contact record if none exists' do
      contact = Postoffice::ContactService.add_or_update_address_book_contact @person1, @person3
      contact.must_be_instance_of Postoffice::Contact
    end

    it 'must update an existing contact record if none exists' do
      Postoffice::ContactService.add_penpal_contact @person1, @person3
      contact = Postoffice::ContactService.add_or_update_address_book_contact @person1, @person3
      contact.in_address_book.must_equal true
    end

    it 'must not update the contact if it is already a penpal' do
      Postoffice::ContactService.add_address_book_contact @person1, @person3
      contact = Postoffice::ContactService.add_or_update_address_book_contact @person1, @person3
      contact.must_equal nil
    end

  end

end

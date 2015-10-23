require_relative '../../spec_helper'

describe Postoffice::QueueItem do

  describe 'create queue item' do

    before do
      @person = build(:person, username: random_username)
      @queue_item = build(:queue_item, person_id: @person.id)
    end

    it 'must create a Postoffice::QueueItem' do
      @queue_item.must_be_instance_of Postoffice::QueueItem
    end

    it 'must store the person id' do
      @queue_item.person_id.must_equal @person.id
    end

    it 'must have a description' do
      @queue_item.description.must_be_instance_of String
    end

    it 'must have a status' do
      @queue_item.status.must_be_instance_of String
    end

    it 'must have an index ensuring uniqueness for description and person' do
      item1 = create(:queue_item, person_id: @person.id, description: "Something")
      assert_raises Mongo::Error::OperationFailure do
        item2 = create(:queue_item, person_id: @person.id, description: "Something")
      end
    end


  end

end

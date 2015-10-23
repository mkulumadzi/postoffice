require_relative '../../spec_helper'

describe Postoffice::QueueService do

  before do
    @person = build(:person, username: random_username)
  end

	describe 'log action occurence' do

    it 'must mark an existing queue item as DONE if one already exists' do
      item = create(:queue_item, description: "THIS_NEEDS_DOING", person_id: @person.id, status: "OPEN")
      Postoffice::QueueService.log_action_occurrence "THIS_NEEDS_DOING", @person.id
      Postoffice::QueueItem.where(description: "THIS_NEEDS_DOING", person_id: @person.id, status: "DONE").exists?.must_equal true
    end

    it 'must create a new queue item and mark it as DONE if one does not alreaady exist' do
      Postoffice::QueueService.log_action_occurrence "THIS_ALSO_NEEDS_DOING", @person.id
      Postoffice::QueueItem.where(description: "THIS_ALSO_NEEDS_DOING", person_id: @person.id, status: "DONE").exists?.must_equal true
    end

	end

  describe 'action has occorred?' do

    it 'must return true if an action has been marked as done for this person' do
      Postoffice::QueueService.log_action_occurrence "THIS_NEEDS_DOING", @person.id
      Postoffice::QueueService.action_has_occurred?("THIS_NEEDS_DOING", @person.id).must_equal true
    end

    it 'must return false if no related queue item exists for that person' do
      Postoffice::QueueService.action_has_occurred?("THIS_ALSO_NEEDS_DOING", @person.id).must_equal false
    end

    it 'must return false if a related queue item exists for that person but it is not DONE' do
      create(:queue_item, description: "THIS_ALSO_NEEDS_DOING", person_id: @person.id, status: "OPEN")
      Postoffice::QueueService.action_has_occurred?("THIS_ALSO_NEEDS_DOING", @person.id).must_equal false
    end

  end

end

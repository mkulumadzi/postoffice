require_relative '../../spec_helper'

describe Postoffice::ContactService do

  before do

    ## Loading test users from Facebook

    @main_facebook_person_email = "wzjjbxh_lison_1449630143@tfbnw.net"
    if Postoffice::Person.where(email: @main_facebook_person_email).count == 0
      create(:person, username: random_username, email: @main_facebook_person_email, facebook_id: "103485133357479", facebook_token: "CAAF497CdlJ0BAAJIM8h1DQ00ZCNh3RZCuyvUrZB7I3Xlf7ZAuf4lO6E72Wjb3JSruZCu6MthzXg2XOjY5QoCw0hQgglWHzCh4iebIWuNe6RdeG4FZC7aCamnZCahuQf0nsYIqS5CsElbEl5kAKPXduGnNZBPuUGdLHRvlLKMuOqVBvjJG8XU7KwnJ8kB34DepVWlOgKEI1HwcgZDZD")
    end
    @main_person = Postoffice::Person.find_by(email: @main_facebook_person_email)

    @friend_facebook_id = "123662334669702"
    if Postoffice::Person.where(facebook_id: @friend_facebook_id).count == 0
      create(:person, username: random_username, email: "khpmlbi_schrocksky_1449630136@tfbnw.net", facebook_id: @friend_facebook_id)
    end
    @friend = Postoffice::Person.find_by(facebook_id: @friend_facebook_id)


    #Creating some other users
    @to_person = create(:person, username: random_username, email: "#{random_username}@test.com")
    @to_mail = create(:mail, correspondents: [build(:from_person, person_id: @main_person.id),build(:to_person, person_id: @to_person.id)])
    @to_mail.conversation

    @from_person = create(:person, username: random_username, email: "#{random_username}@test.com")
    @from_mail = create(:mail, correspondents: [build(:from_person, person_id: @from_person.id),build(:to_person, person_id: @main_person.id)])
    @from_mail.mail_it
    @from_mail.deliver
    @from_mail.conversation

  end

  describe 'get contacts for person' do

    describe 'get facebook friends for person' do

      describe 'get json_document_of_person_facebook_friends' do

        describe 'successful request' do

          before do
            @facebook_json = Postoffice::ContactService.get_json_document_of_person_facebook_friends @main_person.facebook_token
          end

          it 'must return an Array' do
            @facebook_json.must_be_instance_of Array
          end

          it 'the array must contain JSON documents parsed as hashes' do
            @facebook_json[0].must_be_instance_of Hash
          end

          it 'must include the facebook ids for each person in the hashes' do
            @facebook_json[0]["id"].must_be_instance_of String
          end

        end

        describe 'bad request' do

          it 'must return nil' do
            Postoffice::ContactService.get_json_document_of_person_facebook_friends("abc").must_equal nil
          end

        end

      end

      describe 'get people from facebook json' do

        before do
          @facebook_json = Postoffice::ContactService.get_json_document_of_person_facebook_friends @main_person.facebook_token
          @friends = Postoffice::ContactService.get_people_from_facebook_json @facebook_json
        end

        it 'must return an array' do
          @friends.must_be_instance_of Array
        end

        it 'must include people in the array' do
          @friends[0].must_be_instance_of Postoffice::Person
        end

        it 'must have returned people who are facebook friends with the person, using their facebook ids' do
          expected_person = @friends.select { |person| person.facebook_id == @friend_facebook_id }[0]
          expected_person.must_be_instance_of Postoffice::Person
        end

        it 'must return an empty array if the person has no facebook friends' do
          no_friends_json = @facebook_json
          no_friends_json.each { |record| record["id"] = "abc" }
          Postoffice::ContactService.get_people_from_facebook_json(no_friends_json).must_equal []
        end

      end

      it 'must return a persons facebook friends' do
        friends = Postoffice::ContactService.get_facebook_friends_for_person @main_person
        friends[0].must_be_instance_of Postoffice::Person
      end

      it 'must return an empty array if the person does not have an access token' do
        Postoffice::ContactService.get_facebook_friends_for_person(@to_person).must_equal []
      end

    end

    describe 'successful request' do

      before do
        params = Hash.new
        @contacts = Postoffice::ContactService.get_contacts_for_person @main_person, params
      end

      it 'must return an array of people' do
        @contacts[0].must_be_instance_of Postoffice::Person
      end

      it 'must return people who are facebook friends with the person' do
        @contacts.select {|p| p.facebook_id == @friend_facebook_id }[0].must_be_instance_of Postoffice::Person
      end

      it 'must return people who the person has written to' do
        @contacts.select {|p| p.id == @to_person.id }[0].must_be_instance_of Postoffice::Person
      end

      it 'must return people who the person has received mail from' do
        @contacts.select {|p| p.id == @from_person.id }[0].must_be_instance_of Postoffice::Person
      end

      it 'must return the person' do
        @contacts.select {|p| p.id == @main_person.id }[0].must_be_instance_of Postoffice::Person
      end

      it 'must return unique records for each person' do
        @contacts.uniq.must_equal @contacts
      end

    end

  end


end

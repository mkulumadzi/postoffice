require_relative '../../spec_helper'

describe Postoffice::Token do

  describe 'log token by saving it to the database' do

    before do
      person = build(:person, username: random_username)
      @token = Postoffice::AuthService.get_password_reset_token person
      @db_token = Postoffice::Token.new(value: @token)
    end

    it 'must save the token to the database' do
      @db_token.value.must_equal @token
    end

    it 'must include a unique index for the token value' do
      assert_raises Mongo::Error::OperationFailure do
        @db_token.save
        new_token = Postoffice::Token.new(value: @token)
        new_token.save
      end
    end

  end

  describe 'mark as invalid' do

    before do
      @token = Postoffice::AuthService.get_test_token
      db_token = Postoffice::Token.create(value: @token)
      db_token.save
      db_token.mark_as_invalid
    end

    it 'must mark the token as invalid' do
      db_token = Postoffice::Token.find_by(value: @token)
      db_token.is_invalid.must_equal true
    end

  end

  describe 'mark as valid' do

    before do
      @token = Postoffice::AuthService.get_test_token
      db_token = Postoffice::Token.create(value: @token)
      db_token.save
      db_token.mark_as_valid
    end

    it 'must mark the token as valid' do
      db_token = Postoffice::Token.find_by(value: @token)
      db_token.is_invalid.must_equal false
    end

  end

end

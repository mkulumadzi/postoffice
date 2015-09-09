require_relative '../../spec_helper'

describe Postoffice::Token do

  describe 'log token by saving it to the database' do

    before do
      person = build(:person, username: random_username)
      @token = Postoffice::AuthService.generate_password_reset_token person
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

    it 'must be able to be manually flagged as invalid so that it cannot be used again' do
      @db_token.mark_as_invalid
      @db_token.is_invalid.must_equal true
    end

  end

end

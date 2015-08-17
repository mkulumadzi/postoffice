require_relative '../../spec_helper'

describe Postoffice::AuthService do

	Mongoid.load!('config/mongoid.yml')

	before do
		@person = build(:person, username: random_username)
	end

	it 'must be able to open the private key' do
		key = Postoffice::AuthService.get_private_key
		key.private?.must_equal true
	end

	it 'must be able to open the public key' do
		key = Postoffice::AuthService.get_public_key
		key.public?.must_equal true
	end

	describe 'create payload for the user' do

		it 'must generate an expiration date that is 3 months in the future' do
			expiration_integer = Postoffice::AuthService.generate_expiration_date_for_token
			just_less_than_3_months = Time.now.to_i + 3600 * 24 * 72 - 60
			assert_operator expiration_integer, :>=, just_less_than_3_months
		end

		describe 'the payload' do

			before do
				@payload = Postoffice::AuthService.generate_payload_for_person @person
			end

			it 'must return a hash with the user id as a string' do
				@payload[:id].must_equal @person.id.to_s
			end

			it 'must also return the expiration date as an integer' do
				@payload[:exp].must_be_instance_of Fixnum
			end

		end

	end

	describe 'generate the token' do

		before do
			@token = Postoffice::AuthService.generate_token_for_person @person
		end

		it 'must return the token as a string' do
			@token.must_be_instance_of String
		end

		it 'must return a token that can be decoded to get the payload' do
			public_key = Postoffice::AuthService.get_public_key
			decoded_token = JWT.decode @token, public_key
			decoded_token[0]["id"].must_equal @person.id.to_s
		end

	end

end

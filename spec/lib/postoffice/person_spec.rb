require_relative '../../spec_helper'

describe Postoffice::Person do

	before do
		@person = build(:person)
		@expected_attrs = attributes_for(:person)
	end

	describe 'create a person' do

		describe 'store the fields' do

			it 'must create a new person record' do
				@person.must_be_instance_of Postoffice::Person
			end

			it 'must store the username' do
				@person.username.must_equal @expected_attrs[:username]
			end

			it 'must thrown an error if a record is submitted with a duplicate username' do
				person = create(:person, username: random_username)
				assert_raises(Mongo::Error::OperationFailure) {
					Postoffice::Person.create!(
						username: person.username,
						name: "test",
						email: "test@test.com",
						phone: "5554441234"
					)
				}
			end

			it 'must store the name' do
				@person.name.must_equal @expected_attrs[:name]
			end

			it 'must store the email' do
				@person.email.must_equal @expected_attrs[:email]
			end

			it 'must store the phone' do
				@person.phone.must_equal @expected_attrs[:phone]
			end

			it 'must store the address' do
				@person.address1.must_equal @expected_attrs[:address1]
			end

			it 'must store the city' do
				@person.city.must_equal @expected_attrs[:city]
			end

			it 'must store the state' do
				@person.state.must_equal @expected_attrs[:state]
			end

			it 'must store the zip code' do
				@person.zip.must_equal @expected_attrs[:zip]
			end

			it 'must store the salt' do
				@person.salt.must_equal @expected_attrs[:salt]
			end

			it 'must store the hashed password' do
				@person.hashed_password.must_equal @expected_attrs[:hashed_password]
			end

			it 'must store the device token' do
				@person.device_token.must_equal @expected_attrs[:device_token]
			end

		end

	end

	describe 'initials' do

		it 'must return the first letter of the first and last name, if two names are given' do
			person = build(:person, name: "Test Person")
			person.initials.must_equal "TP"
		end

		it 'must return the first two letters of the name if only one name is given' do
			person = build(:person, name: "Test")
			person.initials.must_equal "Te"
		end

	end

end

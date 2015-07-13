require_relative '../../spec_helper'

describe SnailMail::Person do

	let ( :person1 ) {
		person1_username = SnailMail::Person.random_username
		salt = SecureRandom.hex(64)
		hashed_password = Digest::SHA256.bubblebabble ("password" + salt)
		SnailMail::Person.create!(
			name: "Evan",
			username: "#{person1_username}",
			email: "evan@test.com",
			phone: "555-444-1234",
			address1: "121 W 3rd St",
			city: "New York",
			state: "NY",
			zip: "10012",
			salt: salt,
			hashed_password: hashed_password
		)		
	}

	Mongoid.load!('config/mongoid.yml')

	describe 'create a person' do

		it 'should create a random username' do
			assert_match(/[[:upper:]]{8}/, person1.username)
		end

		describe 'store the fields' do

			it 'must create a new person record' do
				person1.must_be_instance_of SnailMail::Person
			end

			it 'must store the name' do
				person1.name.must_equal 'Evan'
			end

			it 'must store the email' do
				person1.email.must_equal 'evan@test.com'
			end

			it 'must store the phone' do
				person1.phone.must_equal '555-444-1234'
			end

			it 'should create a random username' do
				assert_match(/[[:upper:]]{8}/, person1.username)
			end

			it 'must store the address' do
				person1.address1.must_equal '121 W 3rd St'
			end

			it 'must store the city' do
				person1.city.must_equal 'New York'
			end

			it 'must store the state' do
				person1.state.must_equal 'NY'
			end

			it 'must store the zip code' do
				person1.zip.must_equal '10012'
			end

			it 'must store the salt as a String' do
				person1.salt.must_be_instance_of String
			end

			it 'must store the hashed password as a String' do
				person1.hashed_password.must_be_instance_of String
			end

		end

		describe 'ensure username is unique' do

			it 'must thrown an error if a record is submitted with a duplicate username' do
				assert_raises(Moped::Errors::OperationFailure) {
					SnailMail::Person.create!(
						name: "Evan",
						username: "#{person1.username}",
						address1: "44 Prichard Street"
					)
				}
			end

		end

	end

	describe 'set the device token' do

		before do
			person1.device_token = "abc123"
		end

		it 'must store the device token' do
			person1.device_token.must_equal "abc123"
		end

	end

end
require '../spec_helper'

describe SnailMail::User do 
	describe '::validate_user' do
		it 'should validate that a user exists' do
			user = SnailMail::User.new
			user.name = 'Evan'
			allow(SnailMail::User).to receive(:all).and_return([user])

			name = 'Evan'
			is_valid = SnailMail::User::validate(name)
			expect(is_valid).to be(true)
		end
	end
end
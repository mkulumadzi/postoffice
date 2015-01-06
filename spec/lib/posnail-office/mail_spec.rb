require '../spec_helper'

describe SnailMail::Mail do 
	describe '::validate_mail' do
		it 'should validate that a piece of mail exists' do
			message = SnailMail::Mail.new
			message.to = '1'
			allow(SnailMail::Mail).to receive(:all).and_return([message])

			to = '1'
			is_valid = SnailMail::Mail::validate(to)
			expect(is_valid).to be(true)
		end
	end
end
require_relative '../../spec_helper'

describe SnailMail::Person do 

	describe '::validate_person' do

		before do
			@person = SnailMail::Person.new
			@person.name = 'Evan'
		end

		it 'should validate that a person exists' do
			# allow(SnailMail::Person).to receive(:all).and_return([person])
			name = 'Evan'
			SnailMail::Person::validate(name).should_equal true
		end


	end
end
require_relative '../../spec_helper'

describe SnailMail::Mail do

	Mongoid.load!('config/mongoid.yml')

	before do

		@mail1 = build(:mail)
		@mail2 = build(:mail)

		@expected_attrs = attributes_for(:mail)

	end

	describe 'create mail' do

		it 'must create a new piece of mail' do
			@mail1.must_be_instance_of SnailMail::Mail
		end

		it 'must store the person it is from' do
			@mail1.from.must_equal @expected_attrs[:from]
		end

		it 'must store person it is to' do
			@mail1.to.must_equal @expected_attrs[:to]
		end

		it 'must store the content' do
			@mail1.content.must_equal @expected_attrs[:content]
		end

		describe 'add mail image' do

			before do
				image = File.open('spec/resources/image2.jpg')
				@uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
				image.close

				@mail1.image = Dragonfly.app.fetch(@uid).apply
			end

			it 'must store the Dragonfly UID for the mail' do
				@mail1.image.name.must_equal 'image2.jpg'
			end

		end

		it 'must have a default status of "DRAFT"' do
			@mail1.status.must_equal 'DRAFT'
		end

	end

	describe 'send mail' do

		before do
			@mail1.mail_it
		end

		it 'must calculate the number of days to arrive as 3 or more' do
			assert_operator @mail1.days_to_arrive, :>=, 2
		end

		it 'must calculate the number of days to arrive as 5 or less' do
			assert_operator @mail1.days_to_arrive, :<=, 3
		end

		it 'must generate an arrival date that is three or more days in the future' do
			diff = (@mail1.arrive_when - Time.now).round
			assert_operator diff, :>=, 2 * 86400
		end

		it 'must generate an arrival date that is less than 5 days away' do
			diff = (@mail1.arrive_when - Time.now).round
			assert_operator diff, :<=, 3 * 86400
		end

		it 'must have status of SENT' do
			@mail1.status.must_equal "SENT"
		end

		describe 'try to send mail that has already been sent' do

			it 'must throw an error' do
				assert_raises(ArgumentError) {
					@mail1.mail_it
				}
			end

		end

	end

	describe 'deliver mail now' do

		before do
			@mail1.mail_it
			@mail1.deliver_now
		end

		it 'must not be scheduled to arrive in the future' do
			assert_operator @mail1.scheduled_to_arrive, :<=, Time.now
		end

	end

	describe 'update delivery status' do


		before do

			@mail1.mail_it
			@mail1.deliver_now

			@mail2.mail_it

		end

		it 'must set the status of the mail to DELIVERED for mail that has arrived' do
			@mail1.update_delivery_status
			@mail1.status.must_equal "DELIVERED"
		end

		it 'must not still list the mail status as SENT if the mail has not arrived yet' do
			@mail2.update_delivery_status
			@mail2.status.must_equal "SENT"
		end

		it 'must not change mail that has been read back to delivered' do
			@mail2.deliver_now
			@mail2.update_delivery_status
			@mail2.read
			@mail2.update_delivery_status
			@mail2.status.must_equal "READ"
		end

	end

	describe 'read mail' do

		before do
			@mail1.mail_it
			@mail1.deliver_now
			@mail1.update_delivery_status

			@mail2.mail_it
		end

		it 'must mark status of READ' do
			@mail1.read
			@mail1.status.must_equal "READ"
		end

		it 'must throw an error if mail does not have status of DELIVERED' do
			assert_raises(ArgumentError) {
				@mail2.read
			}
		end

	end

end

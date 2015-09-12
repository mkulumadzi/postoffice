require_relative '../../spec_helper'

describe Postoffice::MailService do

	before do
		@person1 = create(:person, username: random_username)
		@person2 = create(:person, username: random_username)
		@person3 = create(:person, username: random_username)

		@data = '{"content": "Hey what is up", "correspondents": {"to_people": ["' + @person2.id.to_s + '","' + @person3.id.to_s + '"], "emails": ["test@test.com", "test2@test.com"]}}'
	end

	describe 'create mail' do

		# def self.create_mail person_id, data
		# 	mail_hash = self.create_mail_hash person_id, data
		# 	mail = Postoffice::Mail.create!(mail_hash)
		# 	self.add_image mail
		# 	mail
		# end

		before do
			@json_data = JSON.parse(@data)
		end

		describe 'create mail hash' do

			# def self.create_mail_hash person_id, json_data
			# 	mail_hash = self.initialize_mail_hash_with_from_person person_id
			# 	mail_hash = self.add_content mail_hash, data
			# 	mail_hash self.add_correspondents mail_hash, data
			# 	mail_hash = self.set_scheduled_to_arrive mail_hash, data
			# end

			describe 'initialize mail hash with from person' do

				# def self.initialize_mail_hash_with_from_person person_id
				# 	Hash.new[:correspondents, [Postoffice::FromPerson.new(person_id: person.id)]]
				# end

				before do
					@hash = Postoffice::MailService.initialize_mail_hash_with_from_person @person1.id
				end

				it 'must include a single FromPerson in an array for the :correspondents key' do
					@hash[:correspondents][0].must_be_instance_of Postoffice::FromPerson
				end

				it 'must have saved the person_id to the FromPerson' do
					@hash[:correspondents][0].person_id.must_equal @person1.id
				end

			end

			describe 'add content' do

				# def self.add_content mail_hash, data
				# 	mail_hash [:content] = data["content"]
				# 	mail_hash
				# end

				before do
					@mail_hash = Postoffice::MailService.initialize_mail_hash_with_from_person @person1.id
					@mail_hash = Postoffice::MailService.add_content @mail_hash, @json_data
				end

				it 'must have added the content to the mail_hash' do
					@mail_hash[:content].must_equal @json_data["content"]
				end

			end

			describe 'add correspondents' do

				# @data = '{"content": "Hey what is up", "correspondents": ["to_people": ["' + @person2.id.to_s '","' + @person3.id.to_s '"], "emails": ["test@test.com", "test2@test.com"]]}'

				# def self.add_correspondents mail_hash, json_data
				# 	correspondents = self.create_to_person_correspondents json_data
				# 	correspondents += self.create_email_correspondents json_data
				# 	mail_hash[:correspondents] = correspondents
				# 	mail_hash
				# end

				before do
					@mail_hash = Postoffice::MailService.initialize_mail_hash_with_from_person @person1.id
				end

				describe 'create to person correpsondents' do

					# def self.create_to_person_correspondents json_data
					# 	correspondents = []
					# 	to_person_list = json_data["correspondents"]["to_people"]
					# 	if to_person_list
					# 		to_person_list.each do { |id| correspondents << self.create_correspondent_from_person_id_string id } end
					# 	end
					# 	correspondents
					# end

					before do
						@correspondents = Postoffice::MailService.create_to_person_correspondents @json_data
					end

					describe 'create correspondent from person_id_string' do

						# def self.create_correspondent_from_person_id_string person_id_s
						# 	Postoffice::ToPerson.new(person_id: BSON::ObjectId(c["person_id"])
						# end

						before do
							@to_person = Postoffice::MailService.create_correspondent_from_person_id_string @person2.id.to_s
						end

						it 'must create a ToPerson' do
							@to_person.must_be_instance_of Postoffice::ToPerson
						end

						it 'must store the person id as an ObjectId' do
							@to_person.person_id.must_equal @person2.id
						end

					end

					it 'must return an array of to_people correspondents' do
						@correspondents[0].must_be_instance_of Postoffice::ToPerson
					end

					it 'must create a to_person for every record in the data' do
						@correspondents.count.must_equal @json_data["correspondents"]["to_people"].count
					end

					describe 'handle case where data does not contain any to_people' do

						before do
							@json_data = JSON.parse('{"content": "Hey what is up", "correspondents": {"emails": ["test@test.com", "test2@test.com"]}}')
							@correspondents = Postoffice::MailService.create_to_person_correspondents @json_data
						end

						it 'msut return an empty array' do
							@correspondents.must_equal []
						end

					end

					describe 'create email correspondents' do

						# def self.create_email_correspondents json_data
						# 	correspondents = []
						# 	email_list = json_data["correspondents"]["emails"]
						# 	if email_list
						# 		email_list.each do { |email| correspondents << Postoffice::Email.new(email: email } end
						# 	end
						# 	correspondents
						# end

						before do
							@correspondents = Postoffice::MailService.create_email_correspondents @json_data
						end

						it 'must return an array of email correspondents' do
							@correspondents[0].must_be_instance_of Postoffice::Email
						end

						it 'must have stored the email' do
							@correspondents[0].email.must_be_instance_of String
						end

						it 'must create an email for every record in the data' do
							@correspondents.count.must_equal @json_data["correspondents"]["emails"].count
						end

						describe 'handle case where data does not contain any emails' do

							before do
								@json_data = JSON.parse('{"content": "Hey what is up", "correspondents": {"to_people": ["' + @person2.id.to_s + '","' + @person3.id.to_s + '"]}}')
								@correspondents = Postoffice::MailService.create_email_correspondents @json_data
							end

							it 'msut return an empty array' do
								@correspondents.must_equal []
							end

						end

					end

				end

			end

			describe 'set secheduled to arrive' do

				# def self.set_scheduled_to_arrive mail_hash, data
				# 	if data["scheduled_to_arrive"] then
				# 		mail_hash[:scheduled_to_arrive] = data["scheduled_to_arrive"]
				# 		mail_hash[:type] = "SCHEDULED"
				# 		mail_hash
				# 	else
				# 		mail_hash
				# 	end
				# end

				describe 'case where data does include a scheduled arrival date' do

					before do
						@json_data["scheduled_to_arrive"] = (Time.now + 5.minutes).to_s
						@mail_hash = Postoffice::MailService.initialize_mail_hash_with_from_person @person1.id
						@mail_hash = Postoffice::MailService.set_scheduled_to_arrive @mail_hash, @json_data
					end

					it 'must have set the date the mail is scheduled to arrive' do
						@mail_hash[:scheduled_to_arrive].must_equal @json_data["scheduled_to_arrive"]
					end

					it 'must have set the mail type to "SCHEDULED"' do
						@mail_hash[:type].must_equal "SCHEDULED"
					end

				end

				describe 'case where scheduled_to_arrive is not set' do

					before do
						@mail_hash = Postoffice::MailService.initialize_mail_hash_with_from_person @person1.id
						@mail_hash = Postoffice::MailService.set_scheduled_to_arrive @mail_hash, @json_data
					end

					it 'must not have set the date the mail is scheduled to arrive' do
						@mail_hash[:scheduled_to_arrive].must_equal nil
					end

					it 'must have not have set the mail type' do
						@mail_hash[:type].must_equal nil
					end

				end

			end

			describe 'mail hash' do

				before do
					@json_data["scheduled_to_arrive"] = (Time.now + 5.minutes).to_s
					@mail_hash = Postoffice::MailService.create_mail_hash @person1.id, @json_data
				end

				it 'must have the all of the keys it needs to create the mail' do
					@mail_hash.keys.must_equal [:correspondents, :content, :scheduled_to_arrive, :type]
				end

				it 'must be able to be used to create a mail' do
					mail = Postoffice::Mail.create!(@mail_hash)
					mail.must_be_instance_of Postoffice::Mail
				end

			end

		end

		# describe 'add image' do
		#
		# 	# def self.add_image mail, json_data
		# 	# 	if json_data["image_uid"]
		# 	# 		mail.image = Dragonfly.app.fetch(data["image_uid"]).apply
		# 	# 		mail.save
		# 	# 	end
		# 	# end
		#
		# 	before do
		# 		image = File.open('spec/resources/image2.jpg')
		# 		@uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
		# 		image.close
		#
		# 		@json_data["image_uid"] = @uid
		# 		@mail
		#
		# 		correspondent_array = [Hash["person_id", @person2.id]]
		# 		data = Hash["correspondents", correspondent_array, "content", @expected_attrs[:content], "image_uid", @uid]
		# 		@mail4 = Postoffice::MailService.create_mail @person1.id, data
		# 	end
		#
		# 	it 'must add a Dragonfly attachment for the mail capable of getting the image name' do
		# 		@mail4.image.name.must_equal 'image2.jpg'
		# 	end
		#
		# 	it 'must be able to return the mime-type' do
		# 		@mail4.image.mime_type.must_equal "image/jpeg"
		# 	end
		#
		# 	it 'must add a thumbnail' do
		# 		@mail4.thumbnail.mime_type.must_equal "image/jpeg"
		# 	end
		#
		# 	it 'must compress the thumbnail to a height of 96 px' do
		# 		@mail4.thumbnail.height.must_equal 96
		# 	end
		#
		# end

		it 'must return the mail' do
			Postoffice::MailService.create_mail(@person1.id, @data).must_be_instance_of Postoffice::Mail
		end

	end

	# describe 'ensure mail arrives in order in which it was sent' do
	# 	before do
	# 		@personA = create(:person, username: random_username)
	# 		@personB = create(:person, username: random_username)
	#
	# 		@mailA = create(:mail, person: @personA, correspondents: [build(:to_person, person_id: @personB.id)])
	# 		@mailB = create(:mail, person: @personA, correspondents: [build(:to_person, person_id: @personB.id)])
	#
	# 		@mailA.mail_it
	# 		@mailB.mail_it
	# 	end
	#
	# 	it 'must make the arrival date of a mail at least 5 minutes after the latest arriving mail, if the former mail was sent later' do
	# 		@mailA.scheduled_to_arrive = Time.now + 4.days
	# 		@mailA.save
	# 		Postoffice::MailService.ensure_mail_arrives_in_order_it_was_sent @mailB
	# 		updated_mail_record = Postoffice::Mail.find(@mailB.id)
	# 		updated_mail_record.scheduled_to_arrive.to_i.must_equal (@mailA.scheduled_to_arrive + 5.minutes).to_i
	# 	end
	#
	# 	it 'must leave the mail arrival date as is if it is already scheduled to arrive later than the other mail' do
	# 		@mailA.scheduled_to_arrive = Time.now
	# 		@mailA.save
	# 		original_scheduled_date = @mailB.scheduled_to_arrive
	# 		Postoffice::MailService.ensure_mail_arrives_in_order_it_was_sent @mailB
	# 		updated_mail_record = Postoffice::Mail.find(@mailB.id)
	# 		updated_mail_record.scheduled_to_arrive.to_i.must_equal original_scheduled_date.to_i
	# 	end
	#
	# 	it 'must ignore other mail if it does not have a type of "STANDARD"' do
	# 		@mailA.scheduled_to_arrive = Time.now + 4.days
	# 		@mailA.type = "SCHEDULED"
	# 		@mailA.save
	# 		original_scheduled_date = @mailB.scheduled_to_arrive
	# 		Postoffice::MailService.ensure_mail_arrives_in_order_it_was_sent @mailB
	# 		updated_mail_record = Postoffice::Mail.find(@mailB.id)
	# 		updated_mail_record.scheduled_to_arrive.to_i.must_equal original_scheduled_date.to_i
	# 	end
	#
	# end

	describe 'operations to get mail' do

		before do

			@person1 = create(:person, username: random_username)
			@person2 = create(:person, username: random_username)
			@person3 = create(:person, username: random_username)

			@mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
			@mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
			@mail3 = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person1.id)])

			@expected_attrs = attributes_for(:mail)

		end

		# To Do: Come back to this, it's getting tricky...
		# describe 'get mail' do
		#
		# 	it 'must get all of the mail if no parameters are given' do
		# 		num_mail = Postoffice::Mail.count
		# 		mail = Postoffice::MailService.get_mail
		# 		mail.length.must_equal num_mail
		# 	end
		#
		# 	# To Do: Come back to these after converting 'from' and 'to' to a dynamic attribute
		# 	it 'must filter the records by from when it is passed in as a parameter' do
		# 		num_mail = Postoffice::Mail.where({from: @person1.username}).count
		# 		params = Hash[:from, @person1.username]
		# 		mail = Postoffice::MailService.get_mail params
		# 		mail.length.must_equal num_mail
		# 	end
		#
		# 	it 'must filter the records by username and name when both are passed in as a parameter' do
		# 		num_mail = Postoffice::Mail.where({from: @person1.username, to: @person2.username}).count
		# 		params = Hash[:from, @person1.username, :to, @person2.username]
		# 		mail = Postoffice::MailService.get_mail params
		# 		mail.length.must_equal num_mail
		# 	end
		#
		# end

		# describe 'mailbox' do
		#
		# 	before do
		# 		@mail1.mail_it
		# 		@mail1.deliver
		#
		# 		@mail2.mail_it
		# 		@params = Hash[:id, @person2.id.to_s]
		# 	end
		#
		# 	describe 'get mailbox' do
		#
		# 		before do
		# 			@mailbox = Postoffice::MailService.mailbox(@params)
		# 		end
		#
		# 		it 'must get mail for the person that has been delivered' do
		# 			filtered_mail = @mailbox.select {|mail| mail.id == @mail1.id}
		# 			filtered_mail.count.must_equal 1
		# 		end
		#
		# 		it 'must not show mail that has not been delivered yet' do
		# 			filtered_mail = @mailbox.select {|mail| mail.id == @mail2.id}
		# 			filtered_mail.count.must_equal 0
		# 		end
		#
		# 	end
		#
		# 	describe 'get only mailbox updates since a datetime' do
		#
		# 		before do
		# 			@mail4 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
		# 			@mail4.mail_it
		# 			@mail4.deliver
		#
		# 			@params[:updated_at] = { "$gt" => @mail2.updated_at }
		# 		end
		#
		# 		it 'must get mailbox records that were updated after the date specified' do
		# 			number_returned = Postoffice::MailService.mailbox(@params).count
		# 			expected_number = Postoffice::Mail.where({status: "DELIVERED", "correspondents.person_id" => @person2.id, updated_at: { "$gt" => @mail2.updated_at }}).count
		# 			number_returned.must_equal expected_number
		# 		end
		#
		# 	end
		#
		# 	# describe 'filter by from person' do
		# 	#
		# 	# 	before do
		# 	# 		@exclude_mail = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person2.id)])
		# 	# 		@exclude_mail.mail_it
		# 	# 		@exclude_mail.deliver
		# 	#
		# 	# 		@params[:conversation_person_id] = @person1.id
		# 	# 		@mailbox = Postoffice::MailService.mailbox(@params)
		# 	# 	end
		# 	#
		# 	# 	it 'must return mail from person 1' do
		# 	# 		filtered_mail = @mailbox.select {|mail| mail[:from_person_id] == @person1.id}
		# 	# 		assert_operator filtered_mail.count, :>=, 1
		# 	# 	end
		# 	#
		# 	# 	it 'must not return mail from person 3' do
		# 	# 		filtered_mail = @mailbox.select {|mail| mail[:from_person_id] == @person3.id}
		# 	# 		filtered_mail.count.must_equal 0
		# 	# 	end
		# 	#
		# 	# end
		#
		# end
		#
		# describe 'outbox' do
		#
		# 	before do
		# 		@mail1.mail_it
		# 		@params1 = Hash[:id, @person1.id]
		# 		@params2 = Hash[:id, @person2.id]
		# 		@mail1.deliver
		# 	end
		#
		# 	describe 'get outbox' do
		#
		# 		before do
		# 			@outbox = Postoffice::MailService.outbox(@params1)
		# 		end
		#
		# 		it 'must get mail that has been sent by the user' do
		# 			filtered_mail = @outbox.select {|mail| mail[:from_person_id] == @person1.id}
		# 			assert_operator filtered_mail.count, :>=, 1
		# 		end
		#
		# 		it 'must not get mail that has been sent by another user' do
		# 			filtered_mail = @outbox.select {|mail| mail[:from_person_id] == @person2.id}
		# 			filtered_mail.count.must_equal 0
		# 		end
		#
		# 	end
		#
		# 	describe 'get only outbox updates since a datetime' do
		#
		# 		before do
		# 			@mail4 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
		# 			@mail4.mail_it
		# 			@mail4.deliver
		# 			@params1[:updated_at] = { "$gt" => @mail1.updated_at }
		# 		end
		#
		# 		it 'must get outbox records that were updated after the date specified' do
		# 			number_returned = Postoffice::MailService.outbox(@params1).count
		# 			expected_number = Postoffice::Mail.where({from_person_id: @person1.id, updated_at: { "$gt" => @mail1.updated_at }}).count
		# 			number_returned.must_equal expected_number
		# 		end
		#
		# 	end
		#
		# 	# describe 'filter by to person' do
		# 	#
		# 	# 	before do
		# 	# 		@exclude_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person3.id)])
		# 	# 		@exclude_mail.mail_it
		# 	# 		@params1[:conversation_person_id] = @person2.id
		# 	# 		@outbox = Postoffice::MailService.outbox(@params1)
		# 	# 	end
		# 	#
		# 	# 	it 'must return mail to person 2' do
		# 	# 		@outbox.to_s.include?(@person2.id.to_s).must_equal true
		# 	# 	end
		# 	#
		# 	# 	it 'must not return mail to person 3' do
		# 	# 		@outbox.to_s.include?(@person3.id.to_s).must_equal false
		# 	# 	end
		# 	#
		# 	# end
		#
		# end

	end

	### Mark: Tests for automated processes that deliver mail and send notifications

	describe 'deliver mail and notify correspondents' do

		before do

			@personA = create(:person, username: random_username)
			@personB = create(:person, username: random_username)
			@personC = create(:person, username: random_username)

			# Mail that has arrived
			@mailA = create(:mail, scheduled_to_arrive: Time.now, status: "SENT", correspondents: [build(:from_person, person_id: @personA.id), build(:to_person, person_id: @personB.id), build(:email, email: "test@test.com")])

			@mailB = create(:mail, scheduled_to_arrive: Time.now, status: "SENT", correspondents: [build(:from_person, person_id: @personA.id), build(:to_person, person_id: @personB.id), build(:to_person, person_id: @personC.id)])

			@mailC = create(:mail, scheduled_to_arrive: Time.now, status: "SENT", correspondents: [build(:from_person, person_id: @personC.id), build(:to_person, person_id: @personA.id), build(:email, email: "test@test.com")])

			# Mail that has not arrived
			@mailD = create(:mail, correspondents: [build(:from_person, person_id: @personB.id), build(:email, email: "test@test.com")])

		end

		describe 'deliver mail that has arrived' do

			describe 'find mail that has arrived' do

				it 'must find mail whose status is SENT and whose scheduled arrival date is in the past' do
					mail_that_has_arrived = Postoffice::MailService.find_mail_that_has_arrived
					mail_that_has_arrived.include?(@mailB).must_equal true
				end

				it 'must not find mail that has not arrived' do
					mail_that_has_arrived = Postoffice::MailService.find_mail_that_has_arrived
					mail_that_has_arrived.include?(@mailD).must_equal false
				end

			end

			describe 'deliver and return mail' do

				before do
					@delivered_mail = Postoffice::MailService.deliver_mail_that_has_arrived
				end

				it 'must return an array of the delivered mail' do
					@delivered_mail[0].must_be_instance_of Postoffice::Mail
				end

				it 'must update the status of all mail that has arrived to DELIVERED' do
					undelivered_mail = (@delivered_mail.select {|mail| mail.status != "DELIVERED" })
					undelivered_mail.count.must_equal 0
				end

			end

		end

		describe 'get correspondents to notify from mail' do

			before do
				correspondent_to_notify = (@mailA.correspondents.select{|correspondent| correspondent._type == "Postoffice::ToPerson"})[0]
				correspondent_to_notify.attempted_to_notify = true
				correspondent_to_notify.save

				correspondent_to_email = (@mailA.correspondents.select{|correspondent| correspondent._type == "Postoffice::Email"})[0]
				correspondent_to_email.attempted_to_send = true
				correspondent_to_email.save

				@delivered_mail = Postoffice::MailService.deliver_mail_that_has_arrived
				@correspondents = Postoffice::MailService.get_correspondents_to_notify_from_mail @delivered_mail
			end

			it 'must return an hash with keys for :to_people correspondents and :email correspondents' do
				@correspondents.keys.must_equal [:to_people, :email]
			end

			describe 'slowpost correspondents' do

				before do
					@slowpost_correspondents = @correspondents[:to_people]
				end

				it 'must return correspondents whose type is Postoffice::ToPerson' do
					correct_type = @slowpost_correspondents.select {|correspondent| correspondent._type == "Postoffice::ToPerson"}
					@slowpost_correspondents.count.must_equal correct_type.count
				end

				it 'must only return correspondents who have not been attempted to be notified yet' do
					not_notified = @slowpost_correspondents.select {|correspondent| correspondent.attempted_to_notify != true}
					@slowpost_correspondents.count.must_equal not_notified.count
				end

			end

			describe 'email correspondents' do

				before do
					@email_correspondents = @correspondents[:email]
				end

				it 'must return correspondents whose type is Postoffice::Email' do
					correct_type = @email_correspondents.select {|correspondent| correspondent._type == "Postoffice::Email"}
					@email_correspondents.count.must_equal correct_type.count
				end

				it 'must only return correspondents who have not had emails attempted to be sent to yet' do
					not_sent = @email_correspondents.select {|correspondent| correspondent.attempted_to_send != true}
					@email_correspondents.count.must_equal not_sent.count
				end

			end

		end

		describe 'send notifications to people receiving mail' do

			before do
				@delivered_mail = Postoffice::MailService.deliver_mail_that_has_arrived
				@slowpost_correspondents = Postoffice::MailService.get_correspondents_to_notify_from_mail(@delivered_mail)[:to_people]
			end

			describe 'get people from correspondents' do

				before do
					@people = Postoffice::MailService.get_people_from_correspondents @slowpost_correspondents
				end

				it 'must return an array of people' do
					@people[0].must_be_instance_of Postoffice::Person
				end

				it 'must return people who are correspondents of the mail' do
					example_person = Postoffice::Person.find(@slowpost_correspondents[0].person_id)
					@people.include?(example_person).must_equal true
				end

			end

			describe 'mark atempted notification of correspondents' do

				before do
					Postoffice::MailService.mark_attempted_notification @slowpost_correspondents
				end

				it 'must indicate that each correspondent has attempted to be notified' do
					not_notified = @slowpost_correspondents.select {|correspondent| correspondent.attempted_to_notify != true }
					not_notified.count.must_equal 0
				end

			end

			# To Do: Figure out how to test that notifications were actually sent
			it 'must not raise an error' do
				Postoffice::MailService.send_notifications_to_people_receiving_mail @slowpost_correspondents
			end

		end

		describe 'send emails for mail' do

			before do
				@delivered_mail = Postoffice::MailService.deliver_mail_that_has_arrived
				@email_correspondents = Postoffice::MailService.get_correspondents_to_notify_from_mail(@delivered_mail)[:email]
			end

			describe 'create emails to send to correspondents' do

				describe 'create email' do

					before do
						@example_correspondent = @email_correspondents[0]
						@hash = Postoffice::MailService.create_email @example_correspondent
					end

					it 'must be from the Postman email account' do
						@hash[:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
					end

					it 'must be to the correct email address' do
						@hash[:to].must_equal "test@test.com"
					end

					it 'must have a subject' do
						@hash[:subject].must_equal "You've received a Slowpost!"
					end

					it 'must have an html body containing the content' do
						@hash[:html_body].must_equal @example_correspondent.mail.content
					end

					it 'must be configured to track opens' do
						@hash[:track_opens].must_equal true
					end

				end

				it 'must return an array of hashes with emails for each correspondent' do
					email_hash = Postoffice::MailService.create_emails_to_send_to_correspondents @email_correspondents
					email_hash[0][:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
				end

			end

			describe 'send email' do

				before do
					@email_hash = Hash[from: "postman@slowpost.me", to: "evan@slowpost.me", subject: "This is a test", html_body: "<strong>Hello</strong> Evan!", track_opens: false]
					@result = Postoffice::MailService.send_email @email_hash
				end

				it 'must not get an error' do
					@result[:error_code].must_equal 0
				end

				it 'must be sent to the right person' do
					@result[:to].must_equal @email_hash[:to]
				end

				it 'must have a unique id' do
					@result[:message_id].must_be_instance_of String
				end

				it 'must indicate that the test job was accpepted' do
					@result[:message].must_equal "Test job accepted"
				end

			end

			describe 'mark attempt to send email' do

				before do
					Postoffice::MailService.mark_attempt_to_send_email @email_correspondents
				end

				it 'must indicate that an email has attempted to be sent to each correspondent' do
					not_notified = @email_correspondents.select {|correspondent| correspondent.attempted_to_send != true }
					not_notified.count.must_equal 0
				end

			end

			# To Do: Figure out how to test that notifications were actually sent
			it 'must not raise an error' do
				Postoffice::MailService.send_emails_for_mail @email_correspondents
			end

		end

		# ## Mark: Tests for conversations
		#
		# describe 'get conversation metadata' do
		#
		# 	before do
		# 		@mail1.mail_it
		# 		@mail1.deliver
		# 		@mail2.mail_it
		# 		@mail2.deliver
		# 		@another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id)])
		# 		@another_mail.mail_it
		#
		# 		@not_slowpost_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:email)])
		# 		@not_slowpost_mail.mail_it
		# 		@not_slowpost_mail.deliver
		#
		# 		@params = Hash[:id, @person2.id]
		# 		@person2_penpals = Postoffice::MailService.get_contacts @params
		# 		@conversation_metadata = Postoffice::MailService.conversation_metadata @params
		# 	end
		#
		# 	it 'must return an array of Hashes' do
		# 		@conversation_metadata[0].must_be_instance_of Hash
		# 	end
		#
		# 	it 'it must return a Hash for each penpal' do
		# 		@conversation_metadata.count.must_equal @person2_penpals.count
		# 	end
		#
		# 	describe 'the metadata' do
		#
		# 		before do
		# 			@metadata_for_person1 = @conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
		# 		end
		#
		# 		it 'must include the username' do
		# 			@metadata_for_person1[:username].must_equal @person1.username
		# 		end
		#
		# 		it 'must include the person name' do
		# 			@metadata_for_person1[:name].must_equal @person2.name
		# 		end
		#
		# 		describe 'unread mail' do
		#
		# 			it 'must include the number of unread mail that is to be delivered by SLOWPOST' do
		# 				mailbox = Postoffice::MailService.mailbox @params
		# 				num_unread = mailbox.select {|mail| mail[:status] != "READ" && mail[:from] == @person1.username && mail[:delivery_options].include?("SLOWPOST")}.count
		# 				@metadata_for_person1[:num_unread].must_equal num_unread
		# 			end
		#
		# 		end
		#
		# 		it 'must include the number of undelivered mail' do
		# 			outbox = Postoffice::MailService.outbox @params
		# 			num_undelivered = outbox.select {|mail| mail[:status] == "SENT" && mail[:to] == @person1.username}.count
		# 			@metadata_for_person1[:num_undelivered].must_equal num_undelivered
		# 		end
		#
		# 		it 'must include the datetime that the most recent mail was updated' do
		# 			@another_mail.updated_at = Time.now + 5.seconds
		# 			@another_mail.save
		# 			conversation_metadata = Postoffice::MailService.conversation_metadata @params
		# 			metadata_for_person1 = conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
		# 			metadata_for_person1[:updated_at].to_i.must_equal @another_mail.updated_at.to_i
		# 		end
		#
		# 		it 'must include the most recent status of a mail' do
		# 			@another_mail.updated_at = Time.now + 5.seconds
		# 			@another_mail.save
		# 			conversation_metadata = Postoffice::MailService.conversation_metadata @params
		# 			metadata_for_person1 = conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
		# 			metadata_for_person1[:most_recent_status].must_equal @another_mail.status
		# 		end
		#
		# 		it 'must include the most recent sender of a mail' do
		# 			@another_mail.updated_at = Time.now + 5.seconds
		# 			@another_mail.save
		# 			conversation_metadata = Postoffice::MailService.conversation_metadata @params
		# 			metadata_for_person1 = conversation_metadata.select { |metadata| metadata[:username] == @person1.username}[0]
		# 			metadata_for_person1[:most_recent_sender].must_equal @another_mail.from
		# 		end
		#
		# 	end
		#
		# 	describe 'get only recent metadata' do
		#
		# 		before do
		# 			recently_updated_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
		# 			recently_updated_mail.mail_it
		# 			recently_updated_mail.updated_at = Time.now + 5.minutes
		# 			recently_updated_mail.save
		#
		# 			one_more_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
		# 			one_more_mail.mail_it
		#
		# 			another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person2.id)])
		# 			another_mail.mail_it
		# 			another_mail.deliver
		#
		# 			params = Hash[:id, @person2.id, :updated_at, { "$gt" => Time.now + 4.minutes }]
		# 			@conversation_metadata = Postoffice::MailService.conversation_metadata params
		#
		# 		end
		#
		# 		it 'must only include people who sent mail or received mail after the date' do
		# 			@conversation_metadata.count.must_equal 1
		# 		end
		#
		# 		it 'must include the total number of unread mail, not just the mail unread since the date' do
		# 			@conversation_metadata[0][:num_unread].must_equal 1
		# 		end
		#
		# 		it 'must include the total number of undelivered mail, not just the mail undelivered since the date' do
		# 			@conversation_metadata[0][:num_undelivered].must_equal 2
		# 		end
		#
		# 	end
		#
		# end
		#
		# describe 'conversation' do
		#
		# 	before do
		# 		@mail1.mail_it
		# 		@mail1.deliver
		#
		# 		@mail2.mail_it
		#
		# 		@include_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id)])
		#
		# 		@exclude_mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person3.id)])
		# 		@exclude_mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person2.id)])
		# 		@exclude_mail2.mail_it
		# 		@exclude_mail2.deliver
		#
		# 		@params = Hash[:id, @person2.id, :conversation_person_id, @person1.id]
		# 		@conversation = Postoffice::MailService.conversation @params
		# 	end
		#
		# 	it 'must include mail from person2 to person 1' do
		# 		@conversation.to_s.include?(@person2.id.to_s).must_equal true
		# 	end
		#
		# 	it 'must not include mail from or to person 3' do
		# 		@conversation.to_s.include?(@person3.id.to_s).must_equal false
		# 	end
		#
		# 	it 'must sort the mail in descending order based on the date it was created' do
		# 		@mail1.created_at = Time.now - 5.days
		# 		sorted_conversation = Postoffice::MailService.conversation @params
		# 		sorted_conversation.pop[:_id].to_s.must_equal @mail1.id.to_s
		# 	end
		#
		# end
		#
		# describe 'get contacts' do
		#
		# 	#Touching mail to create associated mail objects in database
		# 	before do
		# 		@mail1.mail_it
		# 		@mail2.mail_it
		# 		@mail3.mail_it
		#
		# 		@params = Hash[:id, @person1.id.to_s]
		# 	end
		#
		# 	describe 'get users the person has sent mail to' do
		#
		# 		before do
		# 			@correspondents = Postoffice::MailService.get_people_who_received_mail_from @params
		# 		end
		#
		# 		it 'must return an array of people who have received mail from the person' do
		# 			@correspondents[0].must_be_instance_of Postoffice::Person
		# 		end
		#
		# 		# To Do: Come up with a better way to test this; basically just repeating what the function does
		# 		it 'must include every user who has received mail from this person' do
		# 			sent_to = []
		# 			Postoffice::Mail.where(from_person_id: @person1.id).each do |mail|
		# 				mail.correspondents.each do |correspondent|
		# 					sent_to << Postoffice::Person.find(correspondent.person_id)
		# 				end
		# 			end
		# 			(@correspondents.uniq - sent_to.uniq).must_equal []
		# 		end
		#
		# 	end
		#
		# 	describe 'get records where mail was sent since a date' do
		#
		# 		before do
		# 			another_mail = create(:mail, person: @person1, correspondents:[build(:to_person, person_id: @person3.id)])
		# 			another_mail.updated_at = Time.now + 5.minutes
		# 			another_mail.save
		# 			@params[:updated_at] = { "$gt" => Time.now + 4.minutes }
		# 			@correspondents = Postoffice::MailService.get_people_who_received_mail_from @params
		# 		end
		#
		# 		it 'must include people who sent mail to the user after the date specified' do
		# 			@correspondents.must_include @person3
		# 		end
		#
		# 		it 'must not include people who sent mail to the user earlier than the date specified' do
		# 			(@correspondents.include? @person2).must_equal false
		# 		end
		#
		# 	end
		#
		# 	describe 'get users the person has received mail from' do
		#
		# 		before do
		# 			@mail3.deliver
		#
		# 			another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id)])
		# 			another_mail.mail_it
		# 			@senders = Postoffice::MailService.get_people_who_sent_mail_to @params
		# 		end
		#
		# 		it 'must return an array of people' do
		# 			@senders[0].must_be_instance_of Postoffice::Person
		# 		end
		#
		# 		it 'must include every user who has sent mail to this person, if the mail has been delivered already' do
		# 			received_from = []
		# 			Postoffice::Mail.where("correspondents.person_id" => @person1.id, status: "DELIVERED").each do |mail|
		# 				received_from << Postoffice::Person.find(mail.from_person_id)
		# 			end
		# 			(@senders.uniq - received_from.uniq).must_equal []
		# 		end
		#
		# 		it 'must not include users who have sent mail to the person that has not been delivered' do
		# 			@senders.include?(@person2).must_equal false
		# 		end
		#
		# 	end
		#
		# 	describe 'get records where mail was sent since a date' do
		#
		# 		before do
		# 			another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person2.id), build(:to_person, person_id: @person1.id)])
		# 			another_mail.mail_it
		# 			another_mail.deliver
		# 			another_mail.updated_at = Time.now + 5.minutes
		# 			another_mail.save
		# 			@params[:updated_at] = { "$gt" => Time.now + 4.minutes }
		# 			@senders = Postoffice::MailService.get_people_who_sent_mail_to @params
		# 		end
		#
		# 		it 'must include people who sent mail to the user after the date specified' do
		# 			@senders.must_include @person2
		# 		end
		#
		# 		it 'must not include people who sent mail to the user earlier than the date specified' do
		# 			(@senders.include? @person3).must_equal false
		# 		end
		#
		# 	end
		#
		# 	it 'must return an array of bson documents' do
		# 		contacts = Postoffice::MailService.get_contacts @params
		# 		contacts[0].must_be_instance_of BSON::Document
		# 	end
		#
		# 	it 'must create a unique list of all senders and correspondents' do
		# 		senders = Postoffice::MailService.get_people_who_sent_mail_to @params
		# 		correspondents = Postoffice::MailService.get_people_who_received_mail_from @params
		# 		comparison_group = (senders + correspondents).uniq
		# 		comparison_group_as_documents = []
		# 		comparison_group.each do |person|
		# 			comparison_group_as_documents << person.as_document
		# 		end
		#
		# 		contacts = Postoffice::MailService.get_contacts @params
		# 		(contacts - comparison_group_as_documents).must_equal []
		# 	end
		#
		# end

	end

end

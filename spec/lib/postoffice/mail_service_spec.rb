require_relative '../../spec_helper'

describe Postoffice::MailService do

	before do
		@person1 = create(:person, username: random_username)
		@person2 = create(:person, username: random_username)
		@person3 = create(:person, username: random_username)

		image = File.open('spec/resources/image2.jpg')
		@uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
		image.close

		@data = '{"correspondents": {"to_people": ["' + @person2.id.to_s + '","' + @person3.id.to_s + '"], "emails": ["test@test.com", "test2@test.com"]}, "attachments": {"notes": ["Hey what is up"], "image_attachments": ["' + @uid +'"]}}'
	end

	describe 'create mail' do

		before do
			@json_data = JSON.parse(@data)
		end

		describe 'validate recipients' do

			it 'must raise a RuntimeError if a person_id is submitted that is not valid' do
				json_data = JSON.parse('{"correspondents": {"to_people": ["abc"]}}')
				assert_raises RuntimeError do
					Postoffice::MailService.validate_recipients json_data
				end
			end

			it 'must return true if the recipients are valid' do
				json_data = JSON.parse('{"correspondents": {"to_people": ["' + @person2.id + '","' + @person3.id + '"]}}')
				Postoffice::MailService.validate_recipients(json_data).must_equal true
			end

		end

		describe 'create mail hash' do

			describe 'initialize mail hash with from person' do

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

			describe 'add correspondents' do

				before do
					@mail_hash = Postoffice::MailService.initialize_mail_hash_with_from_person @person1.id
				end

				describe 'add embedded documents' do

					before do
						@example_proc = Proc.new { |string| string }
					end

					describe 'source data is not null' do

						before do
							@source_data = ["thing_one", "thing_two"]
							@documents = Postoffice::MailService.add_embedded_documents @source_data, @example_proc
						end

						it 'must call the proc and return an array of the documents that are created' do
							@documents.must_equal @source_data
						end

					end

					describe 'source data is null' do

						it 'must return an empty array' do
							Postoffice::MailService.add_embedded_documents(nil, @example_proc).must_equal []
						end

					end

				end

				describe 'create person correspondent' do

					before do
						@proc = Postoffice::MailService.create_person_correspondent
					end

					it 'must create a ToPerson correspondent when it is called with a person id' do
						@proc.call(@person1.id.to_s).must_be_instance_of Postoffice::ToPerson
					end

					it 'must have stored the person id' do
						to_person = @proc.call(@person1.id.to_s)
						to_person.person_id.must_equal @person1.id
					end

				end

				describe 'create email correspondent' do

					before do
						@proc = Postoffice::MailService.create_email_correspondent
					end

					it 'must create a ToPerson correspondent when it is called with a person id' do
						@proc.call("test@test.com").must_be_instance_of Postoffice::Email
					end

					it 'must have stored the email' do
						email = @proc.call("test@test.com")
						email.email.must_equal "test@test.com"
					end

				end

				describe 'add the correspondents' do

					before do
						@updated_hash = Postoffice::MailService.add_correspondents @mail_hash, @json_data
					end

					it 'must still have the from person' do
						from_person = @updated_hash[:correspondents].select {|c| c._type == "Postoffice::FromPerson"}
						from_person.count.must_equal 1
					end

					it 'must have added people correspondents' do
						to_people = @updated_hash[:correspondents].select {|c| c._type == "Postoffice::ToPerson"}
						assert_operator to_people.count, :>, 0
					end

					it 'must have added email correspondents' do
						emails = @updated_hash[:correspondents].select {|c| c._type == "Postoffice::Email"}
						assert_operator emails.count, :>, 0
					end

				end

			end

			describe 'add attachments' do

				before do
					@mail_hash = Postoffice::MailService.initialize_mail_hash_with_from_person @person1.id
				end

				describe 'add note' do

					before do
						@proc = Postoffice::MailService.add_note
					end

					it 'must create a Note when it is called' do
						@proc.call('Hey what is up').must_be_instance_of Postoffice::Note
					end

					it 'must have stored the content' do
						note = @proc.call('Hey what is up')
						note.content.must_equal "Hey what is up"
					end

				end

				describe 'add image' do

					before do
						@proc = Postoffice::MailService.add_image_attachment
					end

					it 'must create a Note when it is called' do
						@proc.call(@uid).must_be_instance_of Postoffice::ImageAttachment
					end

					it 'must have stored the image uid' do
						image_attachment = @proc.call(@uid)
						image_attachment.image_uid.must_equal @uid
					end

				end

				describe 'add the attachments' do

					before do
						@updated_hash = Postoffice::MailService.add_attachments @mail_hash, @json_data
					end

					it 'must have added an attachments key' do
						@updated_hash.keys.include?(:attachments).must_equal true
					end

					it 'must have added notes' do
						notes = @updated_hash[:attachments].select {|c| c._type == "Postoffice::Note"}
						assert_operator notes.count, :>, 0
					end

					it 'must have added image attachments' do
						image_attachments = @updated_hash[:attachments].select {|c| c._type == "Postoffice::ImageAttachment"}
						assert_operator image_attachments.count, :>, 0
					end

				end

			end

			describe 'set secheduled to arrive' do

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
					expected_keys = [:correspondents, :attachments, :scheduled_to_arrive, :type]
					(expected_keys - @mail_hash.keys).must_equal []
				end

				it 'must be able to be used to create a mail' do
					mail = Postoffice::Mail.create!(@mail_hash)
					mail.must_be_instance_of Postoffice::Mail
				end

			end

		end

		describe 'create conversation if none exists' do

			before do
				@mailA = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com")])
				@mailB = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com")])
			end

			it 'must create the conversation if none exists' do
				Postoffice::MailService.create_conversation_if_none_exists @mailA
				Postoffice::Conversation.where(hex_hash: @mailA.conversation_hash[:hex_hash]).count.must_equal 1
			end

			it 'must not create a duplicate conversation' do
				Postoffice::MailService.create_conversation_if_none_exists @mailB
				Postoffice::Conversation.where(hex_hash: @mailA.conversation_hash[:hex_hash]).count.must_equal 1
			end

		end

		describe 'create the mail' do

			before do
				params = Hash(id: @person1.id.to_s)
				@json_data = JSON.parse(@data)
				@mail = Postoffice::MailService.create_mail(params, @json_data)
			end

			it 'must return the mail' do
				@mail.must_be_instance_of Postoffice::Mail
			end

			it 'must have created the conversation for the mail' do
				Postoffice::Conversation.where(hex_hash: @mail.conversation_hash[:hex_hash]).count.must_equal 1
			end

		end

		describe 'error conditions' do

			before do
				@params = Hash(id: @person1.id.to_s)
				data = '{"correspondents": {"to_people": ["abc"]}, "attachments": {"notes": ["Hey there"]}}'
				@json_data = JSON.parse(data)
			end

			it 'must raise a RuntimeError' do
				assert_raises RuntimeError do
					Postoffice::MailService.create_mail @params, @json_data
				end
			end

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

	describe 'welcome message' do

		before do
			@welcome_mail = Postoffice::MailService.generate_welcome_message @person1
		end

		it 'must be from the postman' do
			@welcome_mail.from_person.must_equal Postoffice::Person.find_by(username: ENV['POSTOFFICE_POSTMAN_USERNAME'])
		end

		describe 'attachments' do

			it 'must have a note attachment with a String for its content' do
				@welcome_mail.notes[0].content.must_be_instance_of String
			end

			it 'must have stored the template content' do
				message_template = File.open("resources/Welcome Message.txt")
				expected_text = message_template.read
				message_template.close

				@welcome_mail.notes[0].content.must_equal expected_text
			end

			it 'must have an image attachment with a String for its uid' do
				@welcome_mail.image_attachments[0].image_uid.must_be_instance_of String
			end

			it 'must have the image uid for the welcome message image' do
				@welcome_mail.image_attachments[0].image_uid.must_equal ENV['POSTOFFICE_WELCOME_IMAGE']
			end

		end

		it 'must have been delivered' do
			@welcome_mail.status.must_equal "DELIVERED"
		end

		it 'must have created the conversation' do
			hash = @welcome_mail.conversation_hash[:hex_hash]
			Postoffice::Conversation.where(hex_hash: hash).count.must_equal 1
		end

	end

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

		describe 'get mail' do

			it 'must get all of the mail if no parameters are given' do
				num_mail = Postoffice::Mail.count
				mail = Postoffice::MailService.get_mail
				mail.count.must_equal num_mail
			end

			# To Do: Come back to these after converting 'from' and 'to' to a dynamic attribute
			it 'must filter the records by a single parameter' do
				num_mail = Postoffice::Mail.where({status: "SENT"}).count
				params = Hash(status: "SENT")
				mail = Postoffice::MailService.get_mail params
				mail.count.must_equal num_mail
			end

			it 'must filter the records by multiple parameters' do
				num_mail = Postoffice::Mail.where({:correspondents.elem_match => {_type: "Postoffice::FromPerson", person_id:  @person1.id}}).count
				params = Hash(:correspondents.elem_match => Hash(_type: "Postoffice::FromPerson", person_id:  @person1.id))
				mail = Postoffice::MailService.get_mail params
				mail.count.must_equal num_mail
			end

		end

		describe 'mailbox' do

			describe 'get person and perform mail query' do

				before do
					@mail1.mail_it
					@mail1.deliver

					@mail2.mail_it
					@mail2.deliver
					@mail2.updated_at = Time.now + 5.minutes
					@mail2.save

					@params = Hash(id: @person2.id.to_s, updated_at: { "$gt" => (Time.now + 4.minutes) })
				end

				describe 'mail query' do

					describe 'create proc for query of mail to person' do

						it 'must return a Proc' do
							Postoffice::MailService.query_mail_to_person.must_be_instance_of Proc
						end

						describe 'call the proc' do

							before do
								@query = Postoffice::MailService.query_mail_to_person.call(@person2)
							end

							it 'must indicate that the status of the mail is DELIVERED' do
								@query[:status].must_equal "DELIVERED"
							end

							it 'must indicate that the correspondens must include a ToPerson that maps to the person.id' do
								@query[:correspondents.elem_match].must_equal Hash("_type" => "Postoffice::ToPerson", "person_id" => @person2.id)
							end

						end

					end

				end

				describe 'add updated since to query' do

					before do
						@query = Postoffice::MailService.query_mail_to_person.call(@person2)
					end

					describe 'params include updated_at' do

						before do
							@query = Postoffice::MailService.add_updated_since_to_query @query, @params
						end

						it 'must have added updated_at to the query' do
							@query[:updated_at].must_equal @params[:updated_at]
						end

						it 'must have preserved the original parts of the query' do
							@query.keys.must_equal [:status, :correspondents.elem_match, :updated_at]
						end

						describe 'query already includes an OR condition' do

							before do
								@or_query = Postoffice::MailService.query_mail_to_person.call(@person2)
								@or_query["$or"] = [{type: "STANDARD"},{type: "SCHEDULED"}]
								@or_query = Postoffice::MailService.add_updated_since_to_query @or_query, @params
							end

							it 'must have preserved the original OR query' do

							end

						end

					end

					describe 'params do not include updated_at' do

						before do
							params = Hash(id: @person2.id.to_s)
							@query = Postoffice::MailService.add_updated_since_to_query @query, params
						end

						it 'must not have added updated_at to the query' do
							@query.keys.include?(:updated_at).must_equal false
						end

					end

				end

				describe 'get mail query using function and params' do

					before do
						mail_query_proc = Postoffice::MailService.query_mail_to_person
						@query = Postoffice::MailService.mail_query mail_query_proc, @person2, @params
					end

					it 'must return the query with all of the keys' do
						@query.keys.must_equal [:status, :correspondents.elem_match, :updated_at]
					end

					it 'must point to the person id' do
						@query[:correspondents.elem_match]["person_id"].must_equal @person2.id
					end

				end

				describe 'return mail array' do

					before do
						mail_query_proc = Postoffice::MailService.query_mail_to_person
						@query = Postoffice::MailService.mail_query mail_query_proc, @person2, @params
						@mail_array = Postoffice::MailService.return_mail_array @query
					end

					it 'must return an array of mail' do
						@mail_array[0].must_be_instance_of Postoffice::Mail
					end

					it 'must return the mail for the query' do
						expected_mail = Postoffice::Mail.where(@query).to_a
						@mail_array.must_equal expected_mail
					end

				end

				describe 'get the mailbox' do

					before do
						@params = Hash(id: @person2.id.to_s)
						@mailbox = Postoffice::MailService.mailbox @params
					end

					it 'must return an array of mail' do
						@mailbox[0].must_be_instance_of Postoffice::Mail
					end

					it 'must include mail that has been sent to the person and has been delivered' do
						@mailbox.include?(@mail1).must_equal true
					end

					it 'must return all of the mail address to that person that has a status of delivered' do
						expected_mail = Postoffice::Mail.where(:status => "DELIVERED", :correspondents.elem_match => {"_type" => "Postoffice::ToPerson", "person_id" => @person2.id}).to_a
						expected_mail.must_equal @mailbox
					end

					it 'must not include mail sent by someone else that has not arrived yet' do
						exclude_mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)])
						exclude_mail.mail_it

						mailbox = Postoffice::MailService.mailbox @params
						mailbox.include?(exclude_mail).must_equal false
					end

					describe 'get mail that was updated since a date' do

						before do
							@params = Hash(id: @person2.id.to_s, updated_at: { "$gt" => (Time.now + 4.minutes) })
							@mailbox = Postoffice::MailService.mailbox @params
						end

						it 'must only return mail that was updated on or after the date specified' do
							filtered_result = @mailbox.select {|mail| mail.updated_at >= (Time.now + 4.minutes)}
							filtered_result.must_equal @mailbox
						end

					end

				end

			end

		end

		describe 'outbox' do

			before do
				@mail1.mail_it
				@mail1.deliver

				@mail2.mail_it
				@mail2.deliver
				@mail2.updated_at = Time.now + 5.minutes
				@mail2.save
			end

			describe 'create a proc for a query that gets the mail sent by a person' do

				it 'must return a Proc' do
					Postoffice::MailService.query_mail_from_person.must_be_instance_of Proc
				end

				describe 'call the proc' do

					before do
						@query = Postoffice::MailService.query_mail_from_person.call(@person1)
					end

					it 'must indicate that the correspondent ToPerson must be this person' do
						@query[:correspondents.elem_match].must_equal Hash("_type" => "Postoffice::FromPerson", "person_id" => @person1.id)
					end

				end

				describe 'get the outbox for a person' do

					before do
						@params = Hash(id: @person1.id)
						@outbox = Postoffice::MailService.outbox @params
					end

					it 'must return an array of mail' do
						@outbox[0].must_be_instance_of Postoffice::Mail
					end

					it 'must include mail that was sent by the person' do
						@outbox.include?(@mail1).must_equal true
					end

					it 'must return all of the mail sent by the person' do
						expected_mail = Postoffice::Mail.where(:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => @person1.id}).to_a
						expected_mail.must_equal @outbox
					end

					it 'must not include mail sent by another person' do
						exclude_mail = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person1.id)])
						outbox = Postoffice::MailService.outbox(@params)
						outbox.include?(exclude_mail).must_equal false
					end

				end

			end

		end

		describe 'all mail for person' do

			before do

				@mail1.mail_it

				@mail2.mail_it
				@mail2.deliver
				@mail2.updated_at = Time.now + 5.minutes
				@mail2.save

				@mail3.mail_it
				@mail3.deliver
			end

			describe 'create a proc for a query that gets all mail for a person' do

				# def self.query_all_mail_for_person
				# 	Proc.new { |person| Hash(or: [{:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => person.id}}, {:status => "DELIVERED", :correspondents.elem_match => {"_type" => "Postoffice::ToPerson", "person_id" => person.id}} ) }
				# end

				it 'must return a Proc' do
					Postoffice::MailService.query_all_mail_for_person.must_be_instance_of Proc
				end

				describe 'call the proc' do

					before do
						@query = Postoffice::MailService.query_all_mail_for_person.call(@person1)
					end

					it 'must return an OR query pointing to an array' do
						@query["$or"].must_be_instance_of Array
					end

					it 'must include the same query as the outbox for the first part of the OR query' do
						@mailbox_query = Postoffice::MailService.query_mail_to_person.call(@person1)
						@mailbox_selector = Postoffice::Mail.where(@mailbox_query).selector
						@query_selector = Postoffice::Mail.where(@query).selector
						@query_selector["$or"][0].must_equal @mailbox_selector
					end

					it 'must include the same query as the outbox for the first part of the OR query' do
						@outbox_query = Postoffice::MailService.query_mail_from_person.call(@person1)
						@outbox_selector = Postoffice::Mail.where(@outbox_query).selector
						@query_selector = Postoffice::Mail.where(@query).selector
						@query_selector["$or"][1].must_equal @outbox_selector
					end

				end

				describe 'get all mail for a person' do

					before do
						@params = Hash(id: @person1.id)
						@all_mail = Postoffice::MailService.all_mail_for_person @params
					end

					it 'must return an array of mail' do
						@all_mail[0].must_be_instance_of Postoffice::Mail
					end

					it 'must include mail that was sent by the person' do
						@all_mail.include?(@mail1).must_equal true
					end

					it 'must include mail that was sent to the person and has been delivered' do
						@all_mail.include?(@mail1).must_equal true
					end

					it 'must not include mail that is not for the person' do
						exclude_mail = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person2.id)])
						exclude_mail.mail_it
						exclude_mail.deliver
						all_mail = Postoffice::MailService.all_mail_for_person(@params)
						all_mail.include?(exclude_mail).must_equal false
					end

					it 'must return all of the mail for the person' do
						expected_mail = Postoffice::Mail.or({:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => @person1.id}},{:status => "DELIVERED", :correspondents.elem_match => {"_type" => "Postoffice::ToPerson", "person_id" => @person1.id}}).to_a
						expected_mail.must_equal @all_mail
					end

				end

			end


		end

	end

	describe 'hash for mail to display for person using an app' do

		before do
			@mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up"), build(:image_attachment, image_uid: @uid)])
			@mail.mail_it
			@mail.deliver
			@mail.read_by @person2
		end

		describe 'mail hash without correspondents key' do

			before do
				@mail_hash = Postoffice::MailService.mail_hash_removing_correspondents_key @mail
			end

			it 'must return a hash' do
				@mail_hash.must_be_instance_of Hash
			end

			it 'must return all of the normal keys except correspondents' do
				normal_keys = JSON.parse(@mail.as_document.to_json).keys
				(normal_keys - @mail_hash.keys).must_equal ["correspondents"]
			end

		end

		describe 'mail info for person' do

			before do
				@correspondent = @mail.correspondents.find_by(person_id: @person2.id)
				@mail_info_for_person = Postoffice::MailService.mail_info_for_person @mail, @person2
			end

			it 'must return the correspondent as a document' do
				@mail_info_for_person.must_equal @correspondent.as_document
			end

		end

		describe 'replace image uids with urls' do

			describe 'mail with image attachments' do

				before do
					@mail_hash = JSON.parse(@mail.as_document.to_json)
					Postoffice::MailService.replace_image_uids_with_urls @mail_hash
					@image_attachment = @mail_hash["attachments"].select {|a| a["_type"] == "Postoffice::ImageAttachment"}[0]
				end

				it 'must have removed the image_uid' do
					@image_attachment["image_uid"].must_equal nil
				end

				it 'must have added a url' do
					@image_attachment["url"].must_be_instance_of String
				end

				it 'must match the image url that the attachment would return' do
					attachment = @mail.attachments.where(_type: "Postoffice::ImageAttachment").first
					expected_url = attachment.url
					@image_attachment["url"].must_equal expected_url
				end

			end

		end

		describe 'generate the hash' do

			before do
				@hash = Postoffice::MailService.hash_of_mail_for_person @mail, @person2
			end

			it 'must return a JSON String' do
				@hash.must_be_instance_of Hash
			end

			it 'must return the custom keys' do
				expected_keys = JSON.parse(@mail.as_document.to_json).keys
				expected_keys.delete("correspondents")
				expected_keys += ["conversation_id", "from_person_id", "to_people_ids", "to_emails", "my_info"]
				(expected_keys - @hash.keys).must_equal []
			end

		end

	end

	### Mark: Tests for automated processes that deliver mail and send notifications

	describe 'deliver mail and notify correspondents' do

		before do

			@personA = create(:person, username: random_username)
			@personB = create(:person, username: random_username)
			@personC = create(:person, username: random_username)

			# Mail that has arrived
			@mailA = create(:mail, scheduled_to_arrive: Time.now, correspondents: [build(:from_person, person_id: @personA.id), build(:to_person, person_id: @personB.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up")])
			@mailA.mail_it

			@mailB = create(:mail, scheduled_to_arrive: Time.now, correspondents: [build(:from_person, person_id: @personA.id), build(:to_person, person_id: @personB.id), build(:to_person, person_id: @personC.id)], attachments: [build(:note, content: "Hey what is up")])
			@mailB.mail_it

			@mailC = create(:mail, scheduled_to_arrive: Time.now, correspondents: [build(:from_person, person_id: @personC.id), build(:to_person, person_id: @personA.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up")])
			@mailC.mail_it

			# Mail that has not arrived
			@mailD = create(:mail, correspondents: [build(:from_person, person_id: @personB.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up")])

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

				@delivered_mail = Postoffice::MailService.deliver_mail_that_has_arrived
				@correspondents = Postoffice::MailService.get_correspondents_to_notify_from_mail @delivered_mail
			end

			it 'must return an hash with keys for :to_people correspondents and :emails correspondents' do
				@correspondents.keys.must_equal [:to_people]
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
			end

			describe 'create emails to send to correspondents' do

				before do
					@emails = Postoffice::MailService.create_emails_to_send_for_mail @delivered_mail
				end

				it 'must return an array of email hashes' do
					@emails[0][:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
				end

				it 'must return an email hash for each correspondent' do
					correspondents = []
					@delivered_mail.each do |mail|
						correspondents += mail.correspondents.where(_type: "Postoffice::Email").to_a
					end
					@emails.length.must_equal correspondents.length
				end

			end

			describe 'send email' do

				before do
					@email_hash = Hash[from: "postman@slowpost.me", to: "evan@slowpost.me", subject: "This is a test", html_body: "<strong>Hello</strong> Evan!", track_opens: false]
					@result = Postoffice::EmailService.send_email @email_hash
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

				it 'must indicate that the test job was accepted' do
					@result[:message].must_equal "Test job accepted"
				end

			end

			# To Do: Figure out how to test that notifications were actually sent
			it 'must not raise an error' do
				Postoffice::MailService.send_emails_for_mail @delivered_mail
			end

		end

		describe 'send the notifications and mail' do

			before do
				Postoffice::MailService.deliver_mail_and_notify_correspondents
			end

			it 'must have marked the mail with notifications sent' do
				mailAdb = Postoffice::Mail.find(@mailA.id)
				to_person = mailAdb.correspondents.select {|c| c._type == "Postoffice::ToPerson"}[0]
				to_person.attempted_to_notify.must_equal true
			end

			it 'must have marked the mail with emails sent' do
				mailAdb = Postoffice::Mail.find(@mailA.id)
				email = mailAdb.correspondents.select {|c| c._type == "Postoffice::Email"}[0]
				email.attempted_to_send.must_equal true
			end

			it 'must not crash if there is no mail to deliver' do
				sleep 1
				Postoffice::MailService.deliver_mail_and_notify_correspondents
			end

		end

	end

end

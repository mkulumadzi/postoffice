require_relative '../../spec_helper'

describe Postoffice::Mail do

	before do

		@person1 = create(:person, username: random_username)
		@person2 = create(:person, username: random_username)
		@person3 = create(:person, username: random_username)

		image = File.open('spec/resources/image2.jpg')
		@uid = Dragonfly.app.store(image.read, 'name' => 'image2.jpg')
		image.close

		@mail1 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up"), build(:image_attachment, image_uid: @uid)])

		@expected_attrs = attributes_for(:mail)

	end

	describe 'create mail' do

		it 'must create a new piece of mail' do
			@mail1.must_be_instance_of Postoffice::Mail
		end

		# it 'must store the person it is from' do
		# 	@mail1.from.must_equal @expected_attrs[:from]
		# end
		#
		# it 'must store person it is to' do
		# 	@mail1.to.must_equal @expected_attrs[:to]
		# end

		it 'must store the content' do
			@mail1.content.must_equal @expected_attrs[:content]
		end

		it 'must record the type of the mail' do
			@mail1.type.must_equal "STANDARD"
		end

		it 'must be able to store the person it is from' do
			@mail1.correspondents.select{|correspondent| correspondent.class == Postoffice::FromPerson}.count.must_equal 1
		end


		it 'must be able to store the person it is to' do
			assert_operator @mail1.correspondents.select{|correspondent| correspondent.class == Postoffice::ToPerson}.count, :>=, 1
		end

		it 'must be able to store an email correspondent' do
			assert_operator @mail1.correspondents.select{|correspondent| correspondent.class == Postoffice::Email}.count, :>=, 1
		end

		it 'must have a default status of "DRAFT"' do
			@mail1.status.must_equal 'DRAFT'
		end

	end

	describe 'cascading callbacks' do

		before do
			@to_person = @mail1.correspondents.select{|correspondent| correspondent.class == Postoffice::ToPerson}[0]
			@to_person.status = "READ"
			sleep 1
			@mail1.save
		end

		it 'must have saved the correspondent records' do
			mail_db_record = Postoffice::Mail.find(@mail1.id)
			to_person_db_record = mail_db_record.correspondents.select{|correspondent| correspondent.class == Postoffice::ToPerson}[0]
			to_person_db_record.status.must_equal "READ"
		end

		it 'must show that the mail was updated at the current date and time' do
			@mail1.updated_at.to_i.must_equal Time.now.to_i
		end

		it 'must show that the correspondent was updated at the current date and time' do
			@to_person.updated_at.to_i.must_equal Time.now.to_i
		end

	end

	describe 'query who the mail is from and to' do

		it 'must be able to find mail addressed to correspondents by their id' do
			Postoffice::Mail.where("correspondents.person_id" => @person2.id).include?(@mail1).must_equal true
		end

		it 'must be able to find mail addressed to emails' do
			Postoffice::Mail.where("correspondents.email" =>"test@test.com").include?(@mail1).must_equal true
		end

	end

	describe 'get attachments from mail' do

		describe 'notes' do

			it 'must return the notes for the mail' do
				@mail1.notes[0].must_be_instance_of Postoffice::Note
			end

		end

		describe 'image attachments' do

			it 'must return the image attachments for the mail' do
				@mail1.image_attachments[0].must_be_instance_of Postoffice::ImageAttachment
			end

		end

	end

	describe 'conversation hash' do

		before do
			@mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person3.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "atest@test.com")])
			@mail3 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person3.id), build(:to_person, person_id: @person2.id)])
		end

		describe 'people correspondents' do

			before do
				@people_correspondents = @mail2.people_correspondent_ids
			end

			it 'must return an array of object_ids' do
				@people_correspondents[0].must_be_instance_of BSON::ObjectId
			end

			it 'must return the person who sent the mail' do
				@people_correspondents.include?(@person1.id).must_equal true
			end

			it 'must include the people the mail was sent to' do
				@people_correspondents.include?(@person2.id).must_equal true
			end

			it 'must have sorted the list of ids ascending' do
				sorted = @people_correspondents.sort {|a,b| a <=> b }
				@people_correspondents.must_equal sorted
			end

		end

		describe 'has email correspondents?' do

			it 'must return true if the mail has email correspondents' do
				@mail2.has_email_correspondents?.must_equal true
			end

			it 'must return false if the mail does not have email correspondents' do
				@mail3.has_email_correspondents?.must_equal false
			end

		end

		describe 'email correspondents' do

			before do
				@email_correspondents = @mail2.email_correspondents
			end

			it 'must return the emails the mail was sent to, sorted ascending' do
				@email_correspondents.must_equal ["atest@test.com", "test@test.com"]
			end

		end

		describe 'add hex hash to conversation hash' do

			before do
				@conversation_hash = Hash(people: @mail2.people_correspondent_ids, email: @mail2.email_correspondents)
				@mail2.add_hex_hash_to_conversation @conversation_hash
			end

			it 'must have created a hex hash of the conversation and added this to the string' do
				hex_hash = Digest::SHA1.hexdigest(Hash(people: @mail2.people_correspondent_ids, email: @mail2.email_correspondents).to_s)
				@conversation_hash[:hex_hash].must_equal hex_hash
			end

		end

		describe 'conversation hash with people and email correspondents' do

			before do
				@conversation_hash = @mail2.conversation_hash
				@people_correspondents = @mail2.people_correspondent_ids
				@email_correspondents = @mail2.email_correspondents
			end

			it 'must include the people corrspondents' do
				@conversation_hash[:people].must_equal @people_correspondents
			end

			it 'must include the email correspondents' do
				@conversation_hash[:emails].must_equal @email_correspondents
			end

			it 'must include the hex hash' do
				@conversation_hash[:hex_hash].must_be_instance_of String
			end

			it 'must be equal to the conversation returned by another mail, with the same people but different roles' do
				another_mail = create(:mail, correspondents: [build(:from_person, person_id: @person3.id), build(:to_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "atest@test.com")])
				another_mail.conversation_hash.must_equal @conversation_hash
			end

		end

		describe 'conversation hash with only people correspondents' do
			before do
				@conversation_hash = @mail3.conversation_hash
			end

			it 'must only include keys for the people and the hex hash' do
				@conversation_hash.keys.must_equal [:people, :hex_hash]
			end

		end

	end

	describe 'conversation' do

		it 'must return a conversation if it already exists' do
			conversation = Postoffice::Conversation.new(@mail1.conversation_hash)
			conversation.save
			@mail1.conversation.must_equal conversation
		end

		it 'must create a new conversation if it does not exist' do
			@mail1.conversation.must_be_instance_of Postoffice::Conversation
		end

	end

	describe 'get the conversation query from a mail' do

		before do
			@person3 = create(:person, username: random_username)
			@person4 = create(:person, username: random_username)
			@mail2 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person3.id), build(:to_person, person_id: @person2.id), build(:to_person, person_id: @person4.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")])
		end

		describe 'initialize conversation query' do

			before do
				@query = @mail2.initialize_conversation_query
			end

			it 'must return a Mongoid Criteria' do
				@query.must_be_instance_of Mongoid::Criteria
			end

			it 'must specify the maximum number of correspondents' do
				num_correspondents = @mail2.correspondents.count
				@query.selector.must_equal Hash["correspondents.#{num_correspondents}", Hash["$exists", false]]
			end

		end

		describe 'add people to conversation query' do

			before do
				@original_query = @mail2.initialize_conversation_query
				@new_query = @mail2.add_people_to_conversation_query @original_query
			end

			it 'must append an all_in selector for the correspondent person_ids' do
				@new_query.selector["correspondents.person_id"]["$all"].must_be_instance_of Array
			end

			it 'must include the FromPerson person_id in the array for that hash' do
				@new_query.selector["correspondents.person_id"]["$all"].include?(@person1.id).must_equal true
			end

			it 'must also include all person_ids fro ToPerson correspondents' do
				expected_array = [@person1.id, @person2.id, @person3.id, @person4.id]
				(@new_query.selector["correspondents.person_id"]["$all"] - expected_array).must_equal []
			end

			it 'must append this query to the original query' do
				num_correspondents = @mail2.correspondents.count
				@new_query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id"]
			end

		end

		describe 'add emails to conversation query' do

			before do
				@original_query = @mail2.initialize_conversation_query
				@people_query = @mail2.add_people_to_conversation_query @original_query
				@email_query = @mail2.add_emails_to_conversation_query @people_query
			end

			it 'must append an all_in selector for the correspondent emails' do
				@email_query.selector["correspondents.email"]["$all"].must_be_instance_of Array
			end

			it 'must include all emails' do
				expected_array = ["test@test.com", "test2@test.com"]
				(@email_query.selector["correspondents.email"]["$all"] - expected_array).must_equal []
			end

			it 'must append this query to the original query' do
				num_correspondents = @mail2.correspondents.count
				@email_query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id", "correspondents.email"]
			end

			describe 'mail with no emails' do

				before do
					@mail3 = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person3.id), build(:to_person, person_id: @person2.id), build(:to_person, person_id: @person4.id)])
					@no_email_query = @mail3.initialize_conversation_query
					@no_email_query = @mail3.add_people_to_conversation_query @no_email_query
					@no_email_query = @mail3.add_emails_to_conversation_query @no_email_query
				end

				it 'must not add a selector for emails' do
					num_correspondents = @mail3.correspondents.count
					@no_email_query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id"]
				end

			end

		end

		describe 'conversation query' do

			before do
				@query = @mail2.conversation_query
			end

			it 'must have all of the selectors' do
				num_correspondents = @mail2.correspondents.count
				@query.selector.keys.must_equal ["correspondents.#{num_correspondents}", "correspondents.person_id", "correspondents.email"]
			end

			it 'must return the mail when it is evaluated' do
				@query.to_a.include?(@mail2).must_equal true
			end

		end

	end

	describe 'send mail' do

		before do
			@mail1.mail_it
		end

		it 'must calculate the number of days to arrive as 1 or more' do
			assert_operator @mail1.days_to_arrive, :>=, 1
		end

		it 'must calculate the number of days to arrive as 2 or less' do
			assert_operator @mail1.days_to_arrive, :<=, 2
		end

		it 'must generate an arrival date that is one or more days in the future' do
			diff = (@mail1.arrive_when - Time.now).round
			assert_operator diff, :>=, 1 * 86400
		end

		it 'must generate an arrival date that is less than 2 days away' do
			diff = (@mail1.arrive_when - Time.now).round
			assert_operator diff, :<=, 2 * 86400
		end

		it 'must have status of SENT' do
			@mail1.status.must_equal "SENT"
		end

		it 'must indicate that it was sent at the current date and time' do
			assert_operator (Time.now.to_i - @mail1.date_sent.to_i), :<=, 100
		end

		describe 'try to send mail that has already been sent' do

			it 'must throw an error' do
				assert_raises(ArgumentError) {
					@mail1.mail_it
				}
			end

		end

	end

	describe 'send mail that has alredy been scheduled' do

		before do
			@scheduled_to_arrive = Time.now + 5.days

			@scheduled_mail = build(:mail)
			@scheduled_mail.type = "SCHEDULED"
			@scheduled_mail.scheduled_to_arrive = @scheduled_to_arrive

			@scheduled_mail.mail_it
		end

		it 'must have status of "SENT"' do
			@scheduled_mail.status.must_equal "SENT"
		end

		it 'must still have the same date it was scheduled to arrive' do
			@scheduled_mail.scheduled_to_arrive.must_equal @scheduled_to_arrive
		end

	end

	describe 'deliver mail' do

		before do
			@mail1.mail_it
			@mail1.deliver
		end

		it 'must update the status to delivered' do
			@mail1.status.must_equal "DELIVERED"
		end

		it 'must set the date and time it was delivered to the current date and time' do
			assert_operator (Time.now.to_i - @mail1.date_delivered.to_i), :<=, 100
		end

	end

	describe 'arrive now' do

		it 'must make the mail arrive now' do
			@mail1.mail_it
			@mail1.arrive_now
			db_record = Postoffice::Mail.find(@mail1.id)
			db_record.scheduled_to_arrive.to_i.must_equal Time.now.to_i
		end

		it 'must return an Argument Error if the mail is not in a sent state' do
			assert_raises ArgumentError do
				@mail1.arrive_now
			end
		end

	end

	describe 'from person' do

		before do
			@from_person = @mail1.from_person
		end

		it 'must return the person' do
			@from_person.must_equal @person1
		end

	end

	describe 'to list' do

		it 'must return a list of all of the peoples names and email addresses it is to' do
			person1 = create(:person, username: random_username, given_name: "Test", family_name: "Person")
			person2 = create(:person, username: random_username, given_name: "Another", family_name: "Test")
			mail = create(:mail, correspondents: [build(:from_person, person_id: person1.id), build(:to_person, person_id: person2.id), build(:email, email: "test@test.com")])

			mail.to_list.must_equal "Another Test, test@test.com"
		end

	end

	describe 'message content' do

		it 'must return the content of the first note' do
			mail = build(:mail, attachments: [build(:note, content: "This is a test")])
			mail.message_content.must_equal "This is a test"
		end

	end

	describe 'to people ids' do

		before do
			@to_people_ids = @mail1.to_people_ids
		end

		it 'must return an array of strings' do
			@to_people_ids[0].must_be_instance_of String
		end

		it 'must return the ids for the people the mail was sent to, as strings' do
			@to_people_ids.must_equal [@person2.id.to_s]
		end

		describe 'mail with no ToPeople' do

			before do
				@no_to_people = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up"), build(:image_attachment, image_uid: @uid)])
			end

			it 'must return an empty array' do
				@no_to_people.to_people_ids.must_equal []
			end

		end

	end

	describe 'to people' do

		before do
			@to_people = @mail1.to_people
		end

		it 'must return an array of people' do
			@to_people[0].must_be_instance_of Postoffice::Person
		end

		it 'must return the people who the mail was sent to' do
			@to_people.must_equal [@person2]
		end

		describe 'mail with invalid correspondents' do

			before do
				@mail_with_invalid_correspondents = build(:mail, correspondents: [build(:to_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:to_person, person_id: "abc")])
			end

			it 'must only return valid people' do
				@mail_with_invalid_correspondents.to_people.must_equal [@person1, @person2]
			end

		end

	end

	describe 'to emails' do

		before do
			@to_emails = @mail1.to_emails
		end

		it 'must return an array of strings' do
			@to_emails[0].must_be_instance_of String
		end

		it 'must return the ids for the people the mail was sent to, as strings' do
			@to_emails.must_equal ["test@test.com"]
		end

		describe 'mail with no Emails' do

			before do
				@no_emails = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)], attachments: [build(:note, content: "Hey what is up"), build(:image_attachment, image_uid: @uid)])
			end

			it 'must return an empty array' do
				@no_emails.to_emails.must_equal []
			end

		end

	end

	describe 'read by person' do

		describe 'read by a recipient' do

			before do
				@mail1.mail_it
				@mail1.deliver
				@mail1.read_by @person2
			end

			it 'must mark that the mail as read by the recipient' do
				correspondent = @mail1.correspondents.find_by(person_id: @person2.id)
				correspondent.status.must_equal "READ"
			end

			describe 'read by someone who is not a ToPerson' do

				it 'must rais a DocumentNotFound error if a person tries to read the mail and they are not a ToPerson' do
					assert_raises Mongoid::Errors::DocumentNotFound do
						@mail1.read_by @person1
					end
				end

			end

		end

		describe 'read mail that has not been DELIVERED yet' do

			it 'must raise a runtime error' do

				assert_raises RuntimeError do
					@mail1.read_by @person2
				end

			end

		end

	end

	describe 'notifications' do

		describe 'notification for sender' do

			before do
				@notifications = @mail1.notification_for_sender
			end

			it 'must return an array with an APNS notification' do
				@notifications[0].must_be_instance_of APNS::Notification
			end

			it 'must only return one notification' do
				@notifications.count.must_equal 1
			end

			it 'must be to the senders device token' do
				@notifications[0].device_token.must_equal @mail1.from_person.device_token
			end

			it 'must tell the sender that their Slowpost has been delivered' do
				@notifications[0].alert.must_equal "Your Slowpost has been delivered"
			end

			it 'must not contain a badge' do
				@notifications[0].badge.must_equal nil
			end

			it 'must be of type Delivered Mail' do
				@notifications[0].other[:type].must_equal "Delivered Mail"
			end

			it 'must return an empty array if the sender does not have a device token' do
				person = create(:person, username: random_username, device_token: nil)
				mail = build(:mail, correspondents: [build(:from_person, person_id: person.id)])
				mail.notification_for_sender.must_equal []
			end

		end

		describe 'notifications for recipients' do

			before do
				@notifications = @mail1.notifications_for_recipients
				@notification = @notifications[0]
			end

			it 'must return an array of notifications' do
				@notification.must_be_instance_of APNS::Notification
			end

			describe 'recipient notification' do

				before do
					@notification = @mail1.recipient_notification @person2
				end

				it 'must be to the recipients device token' do
					@notification.device_token.must_equal @person2.device_token
				end

				it 'must tell the recipient that they have received a Slowpost from the sender' do
					@notification.alert.must_equal "You've received a Slowpost from #{@person1.full_name}"
				end

				it 'must contain a badge with the total number of unread mail for the person' do
					@notification.badge.must_equal @person2.number_unread_mail
				end

				it 'must be of type New Mail' do
					@notification.other[:type].must_equal "New Mail"
				end

			end

			it 'must return the correct recipient notifications' do
				@notification.alert.must_equal @mail1.recipient_notification(@person2).alert
			end

			it 'must only return notifications for recipients who have a device token does not have a device token' do
				sender = create(:person, username: random_username)
				person1 = create(:person, username: random_username, device_token: nil)
				person2 = create(:person, username: random_username, device_token: "abc")
				mail = build(:mail, correspondents: [build(:from_person, person_id: sender.id), build(:to_person, person_id: person1.id), build(:to_person, person_id: person2.id)])
				mail.notification_for_sender.count.must_equal 1
			end

		end

		describe 'the notifications' do

			before do
				@notifications = @mail1.notifications
			end

			it 'must return a notification for all of the people' do
				@notifications.count.must_equal 2
			end

			it 'must return the sender notification' do
				@notifications[0].alert.must_equal @mail1.notification_for_sender[0].alert
			end

			it 'must return the recipient notifications' do
				@notifications[1].alert.must_equal @mail1.recipient_notification(@person2).alert
			end

			it 'must only return notifications for people with device tokens' do
				sender = create(:person, username: random_username, device_token: nil)
				person1 = create(:person, username: random_username, device_token: nil)
				person2 = create(:person, username: random_username, device_token: "abc")
				mail = build(:mail, correspondents: [build(:from_person, person_id: sender.id), build(:to_person, person_id: person1.id), build(:to_person, person_id: person2.id)])
				mail.notifications.count.must_equal 1
			end

		end

	end

	describe 'generate emails for mail' do

		before do
			@mailA = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")], attachments: [build(:note, content: "Hey what is up"), build(:image_attachment, image_uid: @uid)])
			@mailA.mail_it
			@mailA.deliver
		end

		describe 'correspondents to email' do

			before do
				@query = @mailA.correspondents_to_email
			end

			it 'must return a query' do
				@query.must_be_instance_of Mongoid::Criteria
			end

			it 'must return email correspondents for the mail who have not been emailed yet' do
				correspondent = @mailA.correspondents.where(_type: "Postoffice::Email").to_a.first
				@query.to_a[0].must_equal correspondent
			end

			it 'must not return email correspondents for the mail who have already been emailed' do
				emailed = @mailA.correspondents.where(_type: "Postoffice::Email").to_a.first
				emailed.attempted_to_send = true
				emailed.save
				@query.to_a.to_s.include?(emailed.id.to_s).must_equal false
			end

		end

		describe 'email hash' do

			describe 'create image attachment for mail' do

				describe 'create attachment from mail image' do

					describe 'create the image attachment' do

						before do
							@image_attachment = @mailA.image_attachments[0]
							@image_attachment_hash = @mailA.create_attachment_from_mail_image
						end

						it 'must use the image name as the filename, prepended with tmp' do
							@image_attachment_hash["Name"].must_equal "tmp/#{@image_attachment.image.name}"
						end

						it 'must have deleted the temporary file' do
							File.exists?(@image_attachment_hash["Name"]).must_equal false
						end

					end

				end

				describe 'create the attachment' do

					it 'must use the mail image if it has one' do
						image_attachment = @mailA.image_attachments[0]
						expected_name = "tmp/#{image_attachment.image.name}"

						@mailA.mail_image_attachment["Name"].must_equal expected_name
					end

					it 'must use a default card if there is no image attachment' do
						mail = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")], attachments: [build(:note, content: "Hey what is up")])

						mail.mail_image_attachment["Name"].must_equal "resources/default_card.png"
					end

				end

			end

			describe 'generate the email hash' do

				before do
					@correspondnet = @mailA.correspondents.where(_type: "Postoffice::Email").first
					@hash = @mailA.email_hash @correspondnet
				end

				it 'must be from the Postman email account' do
					@hash[:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
				end

				it 'must be to the correct email address' do
					@hash[:to].must_equal @correspondnet.email
				end

				it 'must indicate that the person has received a Slowpost from the sender' do
					expected_subject = "#{@mailA.from_person.full_name} sent you a Slowpost!"
					@hash[:subject].must_equal expected_subject
				end

				it 'must be configured to track opens' do
					@hash[:track_opens].must_equal true
				end

				it 'must add the attachments as an array' do
					@hash[:attachments].must_be_instance_of Array
				end

				it 'must include the Slowpost banner as an attachment' do
					@hash[:attachments][1]["Name"].must_equal "resources/slowpost_banner.png"
				end

				it 'must render the message body using a template' do
					mail_image_attachment = @mailA.mail_image_attachment
					cid = mail_image_attachment["ContentID"]
					variables = Hash(mail: @mailA, image_cid: cid)
					template = "resources/email_template.html"
					expected_result = 				 	Postoffice::EmailService.generate_email_message_body template, variables
					@hash[:html_body].must_equal expected_result
				end

			end

		end

		describe 'create the emails' do

			before do
				@email_correspondents = @mailA.correspondents_to_email.to_a
				@emails = @mailA.emails
			end

			it 'must return an array of email hashes' do
				@emails[0].must_be_instance_of Hash
			end

			it 'must return one email for each correspondent' do
				@emails.length.must_equal @email_correspondents.count
			end

			it 'must be addressed to the correspondents' do
				@emails[0][:to].must_equal @email_correspondents[0].email
			end

			it 'must have indicated that the correspondents have been emailed' do
				@email_correspondents[0].attempted_to_send.must_equal true
			end

		end

		describe 'send preview email if necessary' do

			before do
				@mail_to_preview = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up"), build(:image_attachment, image_uid: @uid)])
				@mail_to_preview.mail_it
			end

			describe 'send preview email' do

				describe 'preview email hash' do

					describe 'to email list shorthand' do

						it 'must return a single email address if the mail has only 1 email recipient' do
							mail = build(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com")], attachments: [build(:note, content: "Hey what is up")])
							mail.to_email_list_shorthand.must_equal "test@test.com"
						end

						it 'must return two email addresses if the mail has 2 email recipients' do
							mail = build(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com")], attachments: [build(:note, content: "Hey what is up")])
							mail.to_email_list_shorthand.must_equal "test@test.com and test2@test.com"
						end

						it 'must return one plus the number remaining if it has more than 2 email recipients' do
							mail = build(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id), build(:email, email: "test@test.com"), build(:email, email: "test2@test.com"), build(:email, email: "test3@test.com")], attachments: [build(:note, content: "Hey what is up")])
							mail.to_email_list_shorthand.must_equal "test@test.com and 2 others"
						end

					end

					before do
						@hash = @mail_to_preview.preview_email_hash
					end

					it 'must return a hash' do
						@hash.must_be_instance_of Hash
					end

					it 'must be from the Postman email account' do
						@hash[:from].must_equal ENV["POSTOFFICE_POSTMAN_EMAIL_ADDRESS"]
					end

					it 'must be to the person who sent the mail' do
						@hash[:to].must_equal @person1.email
					end

					it 'must give a clear description of why they are getting an email' do
						expected_subject = "Preview of your Slowpost to #{@mail_to_preview.to_email_list_shorthand}"
						@hash[:subject].must_equal expected_subject
					end

					it 'must be configured to track opens' do
						@hash[:track_opens].must_equal true
					end

					it 'must add the attachments as an array' do
						@hash[:attachments].must_be_instance_of Array
					end

					it 'must include the Slowpost banner as an attachment' do
						@hash[:attachments][1]["Name"].must_equal "resources/slowpost_banner.png"
					end

					it 'must render the message body using a template' do
						mail_image_attachment = @mail_to_preview.mail_image_attachment
						cid = mail_image_attachment["ContentID"]
						variables = Hash(mail: @mail_to_preview, image_cid: cid)
						template = "resources/preview_email_template.html"
						expected_result = 				 	Postoffice::EmailService.generate_email_message_body template, variables
						@hash[:html_body].must_equal expected_result
					end

				end

				describe 'send the email' do

					before do
						@result = @mail_to_preview.send_preview_email
					end

					it 'must have sent the email' do
						@result[:message].must_equal "Test job accepted"
					end

					it 'must record that the person has had a preview email sent' do
						Postoffice::QueueService.action_has_occurred?("SEND_PREVIEW_EMAIL", @person1.id).must_equal true
					end

				end

			end

			describe 'send the email if necessary' do

				it 'must send a preview email if the mail has email recipients, and the sender has not seen a preview email yet' do
					@mail_to_preview.send_preview_email_if_necessary
					Postoffice::QueueService.action_has_occurred?("SEND_PREVIEW_EMAIL", @person1.id).must_equal true
				end

				it 'must return a hash with the email information if one is sent' do
					@mail_to_preview.send_preview_email_if_necessary.must_be_instance_of Hash
				end

				it 'must not send a preview email if the mail does not include emai recipients' do
					no_preview = create(:mail, correspondents: [build(:from_person, person_id: @person1.id), build(:to_person, person_id: @person2.id)], attachments: [build(:note, content: "Hey what is up"), build(:image_attachment, image_uid: @uid)])
					no_preview.mail_it
					no_preview.send_preview_email_if_necessary
					Postoffice::QueueService.action_has_occurred?("SEND_PREVIEW_EMAIL", @person1.id).must_equal false
				end

				it 'must not send a preview email if person has already received a preview email' do
					Postoffice::QueueService.log_action_occurrence "SEND_PREVIEW_EMAIL", @person1.id
					@mail_to_preview.send_preview_email_if_necessary.must_equal nil
				end

			end

		end

	end

end

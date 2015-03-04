module SnailMail
	class Mail

		def self.get_mail params = {}
			mails = []
			SnailMail::Mail.where(params).each do |mail|
				mails << mail.as_document
			end
			mails
		end

		def self.mailbox params
			username = SnailMail::Person.find(params[:id]).username
			mails = []

			SnailMail::Mail.where({to: username, scheduled_to_arrive: { "$lte" => Time.now } }).each do |mail|
				mails << mail.as_document
			end

			mails
		end

	end
end
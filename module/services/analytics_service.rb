module Postoffice

	class AnalyticsService

    def self.export_mail_metadata
      export_array = []
      Postoffice::Mail.each do |mail|
        export_array << [mail.from_person.full_name, mail.to_list, mail.created_at.to_s, mail.status, mail.scheduled_to_arrive.to_s, mail.updated_at.to_s]
      end
      export_array
    end

		def self.export_email_correspondents
			export_array = []
			export_array << ["From Name", "From username", "From email", "Created", "To Email", "Outcome"]
			Postoffice::Mail.each do |mail|
				person = mail.from_person
				mail.correspondents.where(_type: "Postoffice::Email").each do |email|
					outcome = ""
					if Postoffice::Person.where(email: email.email, created_at: {"$lte" => email.created_at}).count > 0
						outcome = "Already registered"
					elsif Postoffice::Person.where(email: email.email, created_at: {"$gt" => email.created_at}).count > 0
						outcome = "Created account"
					end

					export_array << [person.full_name, person.username, person.email, email.created_at.to_s, email.email, outcome]
				end
			end
			export_array
		end

    def self.export_user_sent_mail_activity
      export_array = []
			export_array << ["Name", "Email", "Username", "Registered", "Received", "Sent", "Sent-SP", "Sent-Em"]

			Postoffice::Person.each do |person|
        registration_date = person.created_at.to_date
        today = Time.now().to_date
        days_active = today - registration_date
        sent_mail_stats = Array.new(days_active + 1){0}
        Postoffice::Mail.where(:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => person.id}).each do |mail|
          mail_created_date = mail.created_at.to_date
          index = (mail_created_date - registration_date).to_i
          sent_mail_stats[index] += 1
        end

				if Postoffice::Mail.where(created_at: {"$lte" => person.created_at}, :correspondents.elem_match => {"_type" => "Postoffice::Email", "email" => person.email}).count > 0
					sent_mail_stats.unshift "true"
				else
					sent_mail_stats.unshift "false"
				end

				sent_mail_stats.unshift Postoffice::Mail.where(:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => person.id}).and(:correspondents.elem_match => {"_type" => "Postoffice::Email"}).count

				sent_mail_stats.unshift Postoffice::Mail.where(:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => person.id}).and(:correspondents.elem_match => {"_type" => "Postoffice::ToPerson"}).count

				sent_mail_stats.unshift Postoffice::Mail.where(:correspondents.elem_match => {"_type" => "Postoffice::FromPerson", "person_id" => person.id}).count

				sent_mail_stats.unshift Postoffice::Mail.where(:correspondents.elem_match => {"_type" => "Postoffice::ToPerson", "person_id" => person.id}).count

        sent_mail_stats.unshift registration_date.to_s
        sent_mail_stats.unshift person.username
        sent_mail_stats.unshift person.email
				sent_mail_stats.unshift person.full_name
        export_array << sent_mail_stats
      end
      export_array
    end

    def self.export_stats filepath

      File.new("#{filepath}/mail_metadata.csv", "w")
      CSV.open("#{filepath}/mail_metadata.csv", "wb") do |csv|
        mail_metadata = self.export_mail_metadata
        mail_metadata.each do |row|
          csv << row
        end
      end

      File.new("#{filepath}/user_sent_mail_activity.csv", "w")
      CSV.open("#{filepath}/user_sent_mail_activity.csv", "wb") do |csv|
        sent_mail_activity = self.export_user_sent_mail_activity
        sent_mail_activity.each do |row|
          csv << row
        end
      end

			File.new("#{filepath}/email_correspondents.csv", "w")
      CSV.open("#{filepath}/email_correspondents.csv", "wb") do |csv|
				email_correspondents = self.export_email_correspondents
        email_correspondents.each do |row|
          csv << row
        end
      end

    end

  end

end

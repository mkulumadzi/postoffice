module Postoffice

	class AnalyticsService

    def self.export_mail_metadata
      export_array = []
      Postoffice::Mail.each do |mail|
        export_array << [mail.from_person.name, mail.to_list, mail.created_at.to_s, mail.image_uid, mail.status, mail.scheduled_to_arrive.to_s, mail.updated_at.to_s]
      end
      export_array
    end

    def self.export_user_sent_mail_activity
      export_array = []
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
        sent_mail_stats.unshift registration_date.to_s
        sent_mail_stats.unshift person.username
        sent_mail_stats.unshift person.email
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

    end

  end

end

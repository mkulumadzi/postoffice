module Postoffice
	class Recipient
		include Mongoid::Document
		include Mongoid::Timestamps
    belongs_to :mail
  end

  class SlowpostRecipient < Recipient
    belongs_to :person
    field :notification_sent, type: DateTime
    field :status, type: String
  end

  class EmailRecipient < Recipient
    field :email, type: String
    field :email_sent, type: DateTime
  end

end

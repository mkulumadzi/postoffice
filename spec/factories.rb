FactoryGirl.define do

  factory :person, class: Postoffice::Person do
    username "testuser"
    name "Test User"
    email "testuser@test.com"
    phone "5554441234"
    address1 "123 4th Street"
    city "New York"
    state "NY"
    zip "10012"
    hashed_password "hash"
    salt "salt"
    device_token "abc123"
  end

  factory :mail, class: Postoffice::Mail do
    person { build(:person) }
    from "a_user"
    to "a_different_user"
    content "I love this app"
    recipients { [build(:email_recipient), build(:slowpost_recipient)] }
  end

  factory :contact, class: Postoffice::Contact do
    person_id "abc"
    contact_person_id "def"
    in_address_book false
    is_penpal true
  end

  factory :email_recipient, class: Postoffice::EmailRecipient do
    email "test@test.com"
  end

  factory :slowpost_recipient, class: Postoffice::SlowpostRecipient do
    person_id "abc"
  end

end

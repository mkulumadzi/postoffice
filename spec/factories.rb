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
    from "a_user"
    to "a_different_user"
    content "I love this app"
  end

  factory :contact, class: Postoffice::Contact do
    person_id "abc"
    contact_person_id "def"
    in_address_book false
    is_penpal true
  end

  factory :email, class: Postoffice::Email do
    email "test@test.com"
  end

  factory :to_person, class: Postoffice::ToPerson do
    person_id "abc"
  end

  factory :from_person, class: Postoffice::FromPerson do
    person_id "abc"
  end



end

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

  factory :note, class: Postoffice::Note do
    content "Hey what is up"
  end

  factory :image_attachment, class: Postoffice::ImageAttachment do
    image_uid "image.jpg"
  end

end

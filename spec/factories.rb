FactoryGirl.define do

  factory :person, class: Postoffice::Person do
    username "testuser"
    given_name "Test"
    family_name "User"
    email "testuser@test.com"
    email_address_validated false
    phone "5554443333"
    hashed_password "hash"
    salt "salt"
    device_token "abc123"
    facebook_id "123"
    facebook_token "abcdef"
  end

  factory :mail, class: Postoffice::Mail do
    attachments { [FactoryGirl.build(:note)] }
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

  factory :queue_item, class: Postoffice::QueueItem do
    person_id "abc"
    description "SHOULD_GET_A_HUG"
    status "OPEN"
  end

end

FactoryGirl.define do

  factory :person, class: SnailMail::Person do
    username "testuser"
    name "Test User"
    email SecureRandom.uuid() + "@test.com"
    phone SecureRandom.uuid()
    address1 "123 4th Street"
    city "New York"
    state "NY"
    zip "10012"
    hashed_password "hash"
    salt "salt"
    device_token "abc123"
  end

  factory :mail, class: SnailMail::Mail do
    from "a_user"
    to "a_different_user"
    content "I love this app"
    image "Default card.png"
  end

end
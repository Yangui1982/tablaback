FactoryBot.define do
  factory :track do
    score { nil }
    name { "MyString" }
    instrument { "MyString" }
    tuning { "MyString" }
    capo { 1 }
    channel { 1 }
  end
end

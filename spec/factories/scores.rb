FactoryBot.define do
  factory :score do
    project { nil }
    title { "MyString" }
    status { "MyString" }
    imported_format { "MyString" }
    key_sig { "MyString" }
    time_sig { "MyString" }
    tempo { 1 }
    doc { "" }
  end
end

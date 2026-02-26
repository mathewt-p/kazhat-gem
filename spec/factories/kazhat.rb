FactoryBot.define do
  factory :kazhat_conversation, class: "Kazhat::Conversation" do
    is_group { false }
    name { nil }

    trait :group do
      is_group { true }
      name { "Group Chat" }
    end
  end

  factory :kazhat_conversation_participant, class: "Kazhat::ConversationParticipant" do
    association :conversation, factory: :kazhat_conversation
    user_id { create(:user).id }
  end

  factory :kazhat_message, class: "Kazhat::Message" do
    association :conversation, factory: :kazhat_conversation
    sender_id { create(:user).id }
    body { "Hello there!" }
    message_type { "text" }
  end

  factory :kazhat_call, class: "Kazhat::Call" do
    association :conversation, factory: :kazhat_conversation
    initiator_id { create(:user).id }
    call_type { "video" }
    status { "ringing" }

    trait :active do
      status { "active" }
      started_at { Time.current }
    end

    trait :ended do
      status { "ended" }
      started_at { 10.minutes.ago }
      ended_at { Time.current }
      duration_seconds { 600 }
    end
  end

  factory :kazhat_call_participant, class: "Kazhat::CallParticipant" do
    association :call, factory: :kazhat_call
    user_id { create(:user).id }
    status { "ringing" }
    rang_at { Time.current }

    trait :joined do
      status { "joined" }
      joined_at { Time.current }
    end

    trait :left do
      status { "left" }
      joined_at { 5.minutes.ago }
      left_at { Time.current }
      duration_seconds { 300 }
    end
  end
end

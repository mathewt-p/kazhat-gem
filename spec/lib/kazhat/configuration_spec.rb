require "rails_helper"

RSpec.describe Kazhat::Configuration do
  subject(:config) { described_class.new }

  describe "defaults" do
    it "sets user_class to User" do
      expect(config.user_class).to eq("User")
    end

    it "sets current_user_method to :current_user" do
      expect(config.current_user_method).to eq(:current_user)
    end

    it "sets max_call_participants to 5" do
      expect(config.max_call_participants).to eq(5)
    end

    it "sets call_timeout to 30" do
      expect(config.call_timeout).to eq(30)
    end

    it "sets default STUN server" do
      expect(config.turn_servers.first[:urls]).to eq("stun:stun.l.google.com:19302")
    end

    it "sets video quality defaults" do
      expect(config.video_quality[2][:width]).to eq(1280)
      expect(config.video_quality[5][:width]).to eq(640)
    end
  end

  describe "#user_class_constant" do
    it "constantizes the user_class string" do
      expect(config.user_class_constant).to eq(User)
    end
  end

  describe "Kazhat.configure" do
    it "allows configuration via block" do
      Kazhat.configure do |c|
        c.max_call_participants = 3
      end

      expect(Kazhat.configuration.max_call_participants).to eq(3)
    end
  end

  describe "Kazhat.reset_configuration!" do
    it "resets to defaults" do
      Kazhat.configure do |c|
        c.max_call_participants = 10
      end

      Kazhat.reset_configuration!
      expect(Kazhat.configuration.max_call_participants).to eq(5)
    end
  end
end

class CreateKazhatConversationParticipants < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_conversation_participants do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :kazhat_conversations }
      t.bigint :user_id, null: false
      t.datetime :last_read_at
      t.timestamps
    end

    add_index :kazhat_conversation_participants,
              [:conversation_id, :user_id],
              unique: true,
              name: "index_kazhat_conv_participants_on_conv_and_user"
    add_index :kazhat_conversation_participants, :user_id
  end
end

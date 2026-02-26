class CreateKazhatMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_messages do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :kazhat_conversations }
      t.bigint :sender_id, null: false
      t.text :body
      t.string :message_type, default: "text", null: false
      t.datetime :edited_at
      t.timestamps
    end

    add_index :kazhat_messages, [:conversation_id, :created_at]
    add_index :kazhat_messages, :sender_id
  end
end

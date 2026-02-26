class CreateKazhatCalls < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_calls do |t|
      t.references :conversation, null: false, foreign_key: { to_table: :kazhat_conversations }
      t.bigint :initiator_id, null: false

      t.string :call_type, null: false, default: "video"
      t.string :status, null: false, default: "ringing"

      t.datetime :started_at
      t.datetime :ended_at
      t.integer :duration_seconds
      t.integer :ring_duration_seconds

      t.integer :max_participants_reached, default: 0
      t.integer :total_participant_seconds, default: 0

      t.timestamps
    end

    add_index :kazhat_calls, :initiator_id
    add_index :kazhat_calls, :status
    add_index :kazhat_calls, :started_at
    add_index :kazhat_calls, [:conversation_id, :created_at]
  end
end

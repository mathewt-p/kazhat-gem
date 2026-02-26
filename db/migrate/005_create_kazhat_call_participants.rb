class CreateKazhatCallParticipants < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_call_participants do |t|
      t.references :call, null: false, foreign_key: { to_table: :kazhat_calls }
      t.bigint :user_id, null: false

      t.string :status, null: false, default: "ringing"

      t.datetime :rang_at
      t.datetime :joined_at
      t.datetime :left_at
      t.integer :duration_seconds

      t.integer :reconnection_count, default: 0
      t.json :quality_stats

      t.timestamps
    end

    add_index :kazhat_call_participants, :user_id
    add_index :kazhat_call_participants,
              [:call_id, :user_id],
              unique: true,
              name: "index_kazhat_call_participants_on_call_and_user"
    add_index :kazhat_call_participants, :joined_at
  end
end

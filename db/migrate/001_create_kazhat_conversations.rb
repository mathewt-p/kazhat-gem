class CreateKazhatConversations < ActiveRecord::Migration[7.0]
  def change
    create_table :kazhat_conversations do |t|
      t.boolean :is_group, default: false, null: false
      t.string :name
      t.timestamps
    end
  end
end

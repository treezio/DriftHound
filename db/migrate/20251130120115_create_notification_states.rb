class CreateNotificationStates < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_states do |t|
      t.references :environment, null: false, foreign_key: true
      t.string :channel, null: false
      t.string :external_id
      t.string :external_channel_id
      t.integer :last_notified_status
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :notification_states, [ :environment_id, :channel ], unique: true
  end
end

class CreateNotificationChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :notification_channels do |t|
      t.references :notifiable, polymorphic: true, null: false
      t.string :channel_type, null: false
      t.boolean :enabled, default: true, null: false
      t.jsonb :config, default: {}

      t.timestamps
    end

    add_index :notification_channels,
              [ :notifiable_type, :notifiable_id, :channel_type ],
              unique: true,
              name: "index_notification_channels_uniqueness"
  end
end

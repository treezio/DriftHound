# frozen_string_literal: true

class InitialSchema < ActiveRecord::Migration[8.0]
  def change
    # Projects table - represents a Terraform project/workspace
    create_table :projects do |t|
      t.string :name, null: false
      t.string :key, null: false

      t.timestamps
    end

    add_index :projects, :key, unique: true

    # Environments table - represents deployment environments (production, staging, etc.)
    create_table :environments do |t|
      t.references :project, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key, null: false
      t.integer :status, default: 0, null: false  # unknown: 0, ok: 1, drift: 2, error: 3
      t.datetime :last_checked_at

      t.timestamps
    end

    add_index :environments, [ :project_id, :key ], unique: true
    add_index :environments, :status

    # Drift checks table - individual terraform plan results
    create_table :drift_checks do |t|
      t.references :environment, null: false, foreign_key: true
      t.integer :status  # unknown: 0, ok: 1, drift: 2, error: 3
      t.integer :add_count
      t.integer :change_count
      t.integer :destroy_count
      t.integer :duration  # execution time in seconds
      t.text :raw_output

      t.timestamps
    end

    add_index :drift_checks, :created_at

    # API tokens table - for authentication
    create_table :api_tokens do |t|
      t.string :name, null: false
      t.string :token, null: false

      t.timestamps
    end

    add_index :api_tokens, :token, unique: true
  end
end

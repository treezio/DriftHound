class CreateAdminUser < ActiveRecord::Migration[8.1]
  def up
    admin_email = ENV["ADMIN_EMAIL"]
    admin_password = ENV["ADMIN_PASSWORD"]

    # In production, require credentials
    if Rails.env.production? && (admin_email.blank? || admin_password.blank?)
      raise <<~ERROR
        ADMIN CREDENTIALS REQUIRED

        Set ADMIN_EMAIL and ADMIN_PASSWORD environment variables before running migrations:

          ADMIN_EMAIL=your@email.com ADMIN_PASSWORD=secure_password rails db:migrate
      ERROR
    end

    # In development/test, skip if not provided
    return if admin_email.blank? || admin_password.blank?

    # Use raw SQL to avoid model dependencies in migrations
    password_digest = BCrypt::Password.create(admin_password)

    execute <<-SQL.squish
      INSERT INTO users (email, password_digest, admin, created_at, updated_at)
      VALUES (#{connection.quote(admin_email)}, #{connection.quote(password_digest)}, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT (email) DO UPDATE SET
        password_digest = #{connection.quote(password_digest)},
        admin = true,
        updated_at = CURRENT_TIMESTAMP
    SQL

    puts "Admin user created/updated: #{admin_email}"
  end

  def down
    # Don't delete users on rollback - too dangerous
  end
end

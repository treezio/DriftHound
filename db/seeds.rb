# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# For development/testing, use the specialized seed tasks:
#
#   bin/rails db:seed:notifications      - Notification testing scenarios (6 scenarios)
#   bin/rails db:seed:edge_cases         - Edge cases (long names, nil values, etc.)
#   bin/rails db:seed:bulk               - Bulk projects and 30 days of historical data
#   bin/rails db:seed:demo               - Curated demo data for screenshots/marketing
#   bin/rails db:seed:all                - Run all development seed tasks
#   bin/rails db:seed:reset              - Clear data and reseed everything
#
# This file only creates the admin user if credentials are provided via environment variables.
# It is safe to run in production.

if ENV["ADMIN_EMAIL"].present? && ENV["ADMIN_PASSWORD"].present?
  admin = User.find_or_initialize_by(email: ENV["ADMIN_EMAIL"])
  admin.password = ENV["ADMIN_PASSWORD"]
  admin.admin = true

  if admin.new_record?
    admin.save!
    puts "Admin user created: #{admin.email}"
  elsif admin.changed?
    admin.save!
    puts "Admin user updated: #{admin.email}"
  else
    puts "Admin user already exists: #{admin.email}"
  end
end

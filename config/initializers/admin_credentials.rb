# Ensure admin credentials are configured in production
#
# In production, you must set:
#   ADMIN_EMAIL    - Email for the admin user
#   ADMIN_PASSWORD - Password for the admin user
#
# Then create the admin user by running:
#   ADMIN_EMAIL=your@email.com ADMIN_PASSWORD=secure_password rails runner "User.create!(email: ENV['ADMIN_EMAIL'], password: ENV['ADMIN_PASSWORD'], admin: true)"
#
# Or in Rails console:
#   User.create!(email: 'your@email.com', password: 'secure_password', admin: true)

# Skip this check during asset precompilation (when SECRET_KEY_BASE_DUMMY is set)
if Rails.env.production? && !ENV["SECRET_KEY_BASE_DUMMY"]
  admin_email = ENV["ADMIN_EMAIL"]
  admin_password = ENV["ADMIN_PASSWORD"]

  if admin_email.blank? || admin_password.blank?
    raise <<~ERROR
      ╔════════════════════════════════════════════════════════════════════════════╗
      ║                     ADMIN CREDENTIALS NOT CONFIGURED                       ║
      ╠════════════════════════════════════════════════════════════════════════════╣
      ║                                                                            ║
      ║  You must set the following environment variables in production:           ║
      ║                                                                            ║
      ║    ADMIN_EMAIL    - Email for the admin user                               ║
      ║    ADMIN_PASSWORD - Password for the admin user (min 6 characters)         ║
      ║                                                                            ║
      ║  After setting the variables, create the admin user:                       ║
      ║                                                                            ║
      ║    rails runner "User.find_or_create_by!(email: ENV['ADMIN_EMAIL']) do |u| ║
      ║      u.password = ENV['ADMIN_PASSWORD']                                    ║
      ║      u.admin = true                                                        ║
      ║    end"                                                                    ║
      ║                                                                            ║
      ╚════════════════════════════════════════════════════════════════════════════╝
    ERROR
  end
end

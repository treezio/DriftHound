# Public Mode Configuration
#
# Controls whether DriftHound requires authentication for viewing content.
#
# PUBLIC_MODE=true  - Anyone can view dashboard, projects, environments, checks
# PUBLIC_MODE=false - Authentication required for all pages (default)
#
# Note: Admin actions (delete, user management, API tokens) always require authentication
# regardless of this setting.

Rails.application.config.public_mode = ENV.fetch("PUBLIC_MODE", "false") == "true"

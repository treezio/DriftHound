# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "=" * 80
puts "DriftHound Notification Testing Seeds"
puts "=" * 80
puts ""

# Clear existing data
DriftCheck.delete_all
NotificationState.delete_all
Environment.delete_all
Project.delete_all
ApiToken.delete_all
User.delete_all

# Create admin user
admin_email = ENV.fetch("ADMIN_EMAIL", "admin")
admin_password = ENV.fetch("ADMIN_PASSWORD", "changeme")
User.create!(email: admin_email, password: admin_password, admin: true)
puts "Admin user created: #{admin_email}"
puts ""

# Create API token
api_token = ApiToken.create!(name: "default-token")
puts "✓ API Token created: #{api_token.token}"
puts ""

# Check if Slack is configured
slack_enabled = Rails.configuration.notifications.dig(:slack, :enabled)
slack_token = Rails.configuration.notifications.dig(:slack, :token)
slack_default_channel = Rails.configuration.notifications.dig(:slack, :default_channel)
slack_configured = slack_enabled && slack_token.present?

# Define different channels for each scenario (for testing purposes)
# You can customize these channels or use environment variables
slack_channels = {
  payments: ENV.fetch("SLACK_CHANNEL_PAYMENTS", "#payments-drift"),
  auth: ENV.fetch("SLACK_CHANNEL_AUTH", "#auth-drift"),
  frontend: ENV.fetch("SLACK_CHANNEL_FRONTEND", "#frontend-drift"),
  api: ENV.fetch("SLACK_CHANNEL_API", "#api-drift"),
  database: ENV.fetch("SLACK_CHANNEL_DATABASE", "#database-drift")
}

puts "Slack Configuration:"
puts "  - Enabled: #{slack_enabled ? '✓ Yes' : '✗ No'}"
puts "  - Token: #{slack_token.present? ? '✓ Configured' : '✗ Missing'}"
puts "  - Default Channel: #{slack_default_channel}"
puts "  - Status: #{slack_configured ? '✓ Ready to send notifications' : '✗ Set SLACK_NOTIFICATIONS_ENABLED=true and SLACK_BOT_TOKEN'}"
puts ""
puts "Channels per project:"
slack_channels.each do |project, channel|
  puts "  - #{project}: #{channel}"
end
puts ""

# Create test projects with different scenarios
puts "Creating test scenarios..."
puts ""

# Scenario 1: Drift Detection
project1 = Project.create!(name: "payment-service", key: "payment-service", repository: "https://github.com/acme/payment-service")
project1.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
  config: { "channel" => slack_channels[:payments] },
  enabled: true
)

env1 = project1.environments.create!(
  name: "Production",
  key: "production",
  last_checked_at: 1.hour.ago,
  directory: "terraform/production"
)

# Create drift check showing drift
env1.drift_checks.create!(
  status: :ok,
  add_count: 0,
  change_count: 0,
  destroy_count: 0,
  duration: 45,
  raw_output: "No changes. Infrastructure matches code.",
  created_at: 2.hours.ago,
  execution_number: 1
)

puts "Scenario 1: Drift Detection (ok → drift)"
puts "  Project: payment-service"
puts "  Environment: Production"
puts "  Expected: 🟡 Drift Detected notification"
env1.update!(status: :ok)
env1.update!(status: :drift)
env1.drift_checks.create!(
  status: :drift,
  add_count: 2,
  change_count: 1,
  destroy_count: 0,
  duration: 52,
  raw_output: "Terraform detected drift:\n  + resource 'db_instance' will be created\n  + resource 'cache_cluster' will be created\n  ~ resource 'app_server' will be updated",
  created_at: Time.current,
  execution_number: 2
)
puts "  ✓ Status changed from 'ok' to 'drift'"
puts ""

# Scenario 1b: Same project, different environment with its own Slack channel
env1b = project1.environments.create!(
  name: "Staging",
  key: "staging",
  last_checked_at: 30.minutes.ago,
  directory: "terraform/staging"
)

# Override the project-level Slack channel for this specific environment
env1b.notification_channels.create!(
  channel_type: "slack",
  config: { "channel" => ENV.fetch("SLACK_CHANNEL_PAYMENTS_STAGING", "#payments-staging") },
  enabled: true
)

env1b.drift_checks.create!(
  status: :ok,
  add_count: 0,
  change_count: 0,
  destroy_count: 0,
  duration: 38,
  raw_output: "No changes. Infrastructure matches code.",
  created_at: Time.current,
  execution_number: 1
)

puts "Scenario 1b: Environment-specific Slack channel"
puts "  Project: payment-service"
puts "  Environment: Staging"
puts "  Project default channel: #{slack_channels[:payments]}"
puts "  Environment override: #{ENV.fetch('SLACK_CHANNEL_PAYMENTS_STAGING', '#payments-staging')}"
puts "  ✓ Staging uses its own Slack channel (overrides project default)"
puts ""

# Scenario 2: Error Detection
project2 = Project.create!(name: "auth-service", key: "auth-service", repository: "https://gitlab.com/acme/auth-service")
project2.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
  config: { "channel" => slack_channels[:auth] },
  enabled: true
)

env2 = project2.environments.create!(
  name: "Staging",
  key: "staging",
  last_checked_at: 30.minutes.ago,
  directory: "infra/staging"
)

puts "Scenario 2: Error Detection (ok → error)"
puts "  Project: auth-service"
puts "  Environment: Staging"
puts "  Expected: 🔴 Error Detected notification"
env2.update!(status: :ok)
env2.update!(status: :error)
env2.drift_checks.create!(
  status: :error,
  add_count: 0,
  change_count: 0,
  destroy_count: 0,
  duration: 15,
  raw_output: "Error: Failed to refresh state\nError: Could not connect to AWS API\nStatus code: 403",
  created_at: Time.current,
  execution_number: 1
)
puts "  ✓ Status changed from 'ok' to 'error'"
puts ""

# Scenario 3: Drift Resolved
project3 = Project.create!(name: "frontend-app", key: "frontend-app", repository: "https://github.com/acme/frontend-app")
project3.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
  config: { "channel" => slack_channels[:frontend] },
  enabled: true
)

env3 = project3.environments.create!(
  name: "Production",
  key: "production",
  last_checked_at: 2.hours.ago,
  directory: "terraform/prod"
)

# First create drift
env3.update!(status: :ok)
env3.update!(status: :drift)
env3.drift_checks.create!(
  status: :drift,
  add_count: 1,
  change_count: 0,
  destroy_count: 0,
  duration: 38,
  raw_output: "Drift detected in CDN configuration",
  created_at: 1.hour.ago,
  execution_number: 1
)

puts "Scenario 3: Drift Resolved (drift → ok)"
puts "  Project: frontend-app"
puts "  Environment: Production"
puts "  Expected: 🟢 Drift Resolved notification"
sleep(0.5) # Small delay to ensure different timestamps
env3.update!(status: :ok)
env3.drift_checks.create!(
  status: :ok,
  add_count: 0,
  change_count: 0,
  destroy_count: 0,
  duration: 42,
  raw_output: "Infrastructure now matches code. Drift resolved.",
  created_at: Time.current,
  execution_number: 2
)
puts "  ✓ Status changed from 'drift' to 'ok'"
puts ""

# Scenario 4: Error Resolved
project4 = Project.create!(name: "api-gateway", key: "api-gateway", repository: "https://github.com/acme/api-gateway")
project4.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
  config: { "channel" => slack_channels[:api] },
  enabled: true
)

env4 = project4.environments.create!(
  name: "Production",
  key: "production",
  last_checked_at: 45.minutes.ago,
  directory: "infrastructure/api"
)

# First create error
env4.update!(status: :ok)
env4.update!(status: :error)
env4.drift_checks.create!(
  status: :error,
  add_count: 0,
  change_count: 0,
  destroy_count: 0,
  duration: 8,
  raw_output: "Terraform state locked by another process",
  created_at: 30.minutes.ago,
  execution_number: 1
)

puts "Scenario 4: Error Resolved (error → ok)"
puts "  Project: api-gateway"
puts "  Environment: Production"
puts "  Expected: 🟢 Error Resolved notification"
sleep(0.5)
env4.update!(status: :ok)
env4.drift_checks.create!(
  status: :ok,
  add_count: 0,
  change_count: 0,
  destroy_count: 0,
  duration: 55,
  raw_output: "State lock released. Infrastructure check completed successfully.",
  created_at: Time.current,
  execution_number: 2
)
puts "  ✓ Status changed from 'error' to 'ok'"
puts ""

# Scenario 5: No notification (lateral move - drift to drift)
project5 = Project.create!(name: "database-service", key: "database-service")
project5.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
  config: { "channel" => slack_channels[:database] },
  enabled: true
)

env5 = project5.environments.create!(
  name: "Production",
  key: "production",
  status: :drift,
  last_checked_at: 20.minutes.ago,
  directory: "terraform/database"
)

puts "Scenario 5: No Notification (drift → drift - lateral move)"
puts "  Project: database-service"
puts "  Environment: Production"
puts "  Expected: ✗ No notification (spam prevention)"
env5.update!(status: :drift) # Same status, should not notify
env5.drift_checks.create!(
  status: :drift,
  add_count: 1,
  change_count: 2,
  destroy_count: 0,
  duration: 61,
  raw_output: "Still drifting with additional changes",
  created_at: Time.current,
  execution_number: 1
)
puts "  ✓ Status unchanged 'drift' → 'drift' (blocked by lateral_move check)"
puts ""

# Scenario 6: Environment without notification channel
project6 = Project.create!(name: "no-notifications", key: "no-notifications")
# Intentionally NOT creating notification channel

env6 = project6.environments.create!(
  name: "Development",
  key: "development",
  last_checked_at: 10.minutes.ago
)

puts "Scenario 6: No Notification Channel Configured"
puts "  Project: no-notifications"
puts "  Environment: Development"
puts "  Expected: ✗ No notification (no channels configured)"
env6.update!(status: :ok)
env6.update!(status: :drift)
puts "  ✓ Status changed 'ok' → 'drift' but no channels configured"
puts ""

# Scenario 7: Long project and environment names (for testing UI overflow)
project7 = Project.create!(
  name: "super-long-project-name-for-enterprise-infrastructure-management-system",
  key: "super-long-project-name-for-enterprise-infrastructure-management-system",
  repository: "https://github.com/acme-corporation/super-long-project-name-for-enterprise-infrastructure-management-system"
)

env7 = project7.environments.create!(
  name: "production-us-east-1-primary-datacenter-cluster-a",
  key: "production-us-east-1-primary-datacenter-cluster-a",
  status: :ok,
  last_checked_at: 5.minutes.ago,
  directory: "terraform/environments/production/us-east-1/primary-datacenter/cluster-a"
)

env7.drift_checks.create!(
  status: :ok,
  add_count: 0,
  change_count: 0,
  destroy_count: 0,
  duration: 120,
  raw_output: "No changes. Infrastructure matches code.",
  created_at: Time.current,
  execution_number: 1
)

puts "Scenario 7: Long Names (UI overflow testing)"
puts "  Project: #{project7.name}"
puts "  Environment: #{env7.name}"
puts "  ✓ Created for testing long name overflow in UI"
puts ""

puts "=" * 80
puts "Summary"
puts "=" * 80
puts "Projects created: #{Project.count}"
puts "Environments created: #{Environment.count}"
puts "Drift checks created: #{DriftCheck.count}"
puts "Notification channels: #{NotificationChannel.count}"
puts ""
puts "Expected Notifications: 6"
puts "  - Scenario 1: Drift Detected (payment-service)"
puts "  - Scenario 2: Error Detected (auth-service)"
puts "  - Scenario 3a: Drift Detected (frontend-app)"
puts "  - Scenario 3b: Drift Resolved (frontend-app)"
puts "  - Scenario 4a: Error Detected (api-gateway)"
puts "  - Scenario 4b: Error Resolved (api-gateway)"
puts ""
puts "Blocked Notifications: 2"
puts "  - Scenario 5: Lateral move (drift→drift)"
puts "  - Scenario 6: No notification channel"
puts ""

if slack_configured
  puts "✓ Check the following Slack channels for notifications:"
  puts ""
  puts "  #{slack_channels[:payments]} → payment-service/production (Project default)"
  puts "  #{ENV.fetch('SLACK_CHANNEL_PAYMENTS_STAGING', '#payments-staging')} → payment-service/staging (Environment override)"
  puts "  #{slack_channels[:auth]} → auth-service (Error Detected)"
  puts "  #{slack_channels[:frontend]} → frontend-app (Drift Detected + Resolved)"
  puts "  #{slack_channels[:api]} → api-gateway (Error Detected + Resolved)"
  puts "  #{slack_channels[:database]} → database-service (No notification - lateral move)"
  puts ""
  puts "Channel inheritance example (payment-service):"
  puts "  - Production env → uses project default: #{slack_channels[:payments]}"
  puts "  - Staging env → uses environment override: #{ENV.fetch('SLACK_CHANNEL_PAYMENTS_STAGING', '#payments-staging')}"
  puts ""
  puts "Note: Jobs are processed with :inline adapter in development."
  puts "      Notifications should appear immediately."
  puts ""
  puts "Expected notification types:"
  puts "  - 2x Drift Detected (orange/yellow)"
  puts "  - 2x Error Detected (red)"
  puts "  - 1x Drift Resolved (green)"
  puts "  - 1x Error Resolved (green)"
else
  puts "⚠ Slack is not configured. Set environment variables to test:"
  puts "  export SLACK_NOTIFICATIONS_ENABLED=true"
  puts "  export SLACK_BOT_TOKEN=xoxb-your-token-here"
  puts ""
  puts "Optionally set custom channels per project:"
  puts "  export SLACK_CHANNEL_PAYMENTS=#your-payments-channel"
  puts "  export SLACK_CHANNEL_AUTH=#your-auth-channel"
  puts "  export SLACK_CHANNEL_FRONTEND=#your-frontend-channel"
  puts "  export SLACK_CHANNEL_API=#your-api-channel"
  puts "  export SLACK_CHANNEL_DATABASE=#your-database-channel"
end
puts "=" * 80

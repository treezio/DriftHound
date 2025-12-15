# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Load demo data for screenshots and marketing materials"
    task demo: :environment do
      puts "=" * 60
      puts "DriftHound Demo Data"
      puts "=" * 60
      puts ""

      # Clear existing data
      DriftCheck.delete_all
      NotificationState.delete_all
      Environment.delete_all
      Project.delete_all
      ApiToken.delete_all
      User.delete_all

      # Create admin user
      User.create!(email: "admin@drifthound.io", password: "demo1234", admin: true)
      puts "Admin user created: admin@drifthound.io"

      # Create API token
      api_token = ApiToken.create!(name: "demo-token")
      puts "API Token created: #{api_token.token}"
      puts ""

      # Demo projects with curated data
      demo_data = [
        { project: "payment-api", environments: [
          { name: "Production", key: "production", status: :ok },
          { name: "Staging", key: "staging", status: :drift }
        ]},
        { project: "user-service", environments: [
          { name: "Production", key: "production", status: :ok }
        ]},
        { project: "web-frontend", environments: [
          { name: "Production", key: "production", status: :drift },
          { name: "Staging", key: "staging", status: :ok }
        ]},
        { project: "analytics-pipeline", environments: [
          { name: "Production", key: "production", status: :ok }
        ]},
        { project: "notification-service", environments: [
          { name: "Production", key: "production", status: :error }
        ]},
        { project: "inventory-api", environments: [
          { name: "Production", key: "production", status: :ok }
        ]},
        { project: "auth-gateway", environments: [
          { name: "Production", key: "production", status: :ok },
          { name: "Staging", key: "staging", status: :drift }
        ]}
      ]

      puts "Creating projects and environments..."
      puts ""

      demo_data.each do |data|
        project = Project.create!(
          name: data[:project],
          key: data[:project],
          repository: "https://github.com/acme/#{data[:project]}"
        )

        data[:environments].each do |env_data|
          env = project.environments.create!(
            name: env_data[:name],
            key: env_data[:key],
            status: env_data[:status],
            last_checked_at: rand(1..4).hours.ago,
            directory: "terraform/#{env_data[:key]}"
          )

          # Generate historical checks for the last 60 days
          generate_demo_history(env, env_data[:status], 60)

          status_icon = case env_data[:status]
                        when :ok then "✓"
                        when :drift then "~"
                        when :error then "✗"
                        end

          puts "  #{status_icon} #{project.name}/#{env.name} (#{env_data[:status]})"
        end
      end

      puts ""
      puts "=" * 60
      puts "Summary"
      puts "=" * 60
      puts "Projects: #{Project.count}"
      puts "Environments: #{Environment.count}"
      puts "Drift Checks: #{DriftCheck.count}"
      puts ""
      puts "Status breakdown:"
      puts "  OK:    #{Environment.where(status: :ok).count}"
      puts "  Drift: #{Environment.where(status: :drift).count}"
      puts "  Error: #{Environment.where(status: :error).count}"
      puts ""
      puts "Login: admin@drifthound.io / demo1234"
      puts "=" * 60
    end
  end
end

def generate_demo_history(env, current_status, days = 30)
  checks_data = []

  # Generate history for specified days
  days.downto(0) do |days_ago|
    # Most days have 1-2 checks, some days skipped (10% chance)
    next if days_ago > 0 && rand < 0.1

    # Number of checks for this day (1-2, occasionally 3)
    checks_per_day = days_ago == 0 ? 1 : [1, 1, 1, 2, 2, 3].sample

    checks_per_day.times do |check_idx|
      # Determine status for this check
      status = if days_ago == 0
                 current_status
               else
                 # Historical data: mostly OK, occasional drift
                 case rand(100)
                 when 0..72 then :ok
                 when 73..88 then :drift
                 else :error
                 end
               end

      # Generate check attributes with spread throughout the day
      base_hour = 8 + (check_idx * 4) # Spread checks: 8am, 12pm, 4pm
      check_time = days_ago.days.ago + base_hour.hours + rand(0..59).minutes

      case status
      when :ok
        checks_data << {
          status: :ok,
          add_count: 0,
          change_count: 0,
          destroy_count: 0,
          duration: rand(30..90),
          raw_output: "No changes. Your infrastructure matches the configuration.",
          created_at: check_time
        }
      when :drift
        add = rand(0..2)
        change = rand(1..4)
        destroy = rand(0..1)
        checks_data << {
          status: :drift,
          add_count: add,
          change_count: change,
          destroy_count: destroy,
          duration: rand(40..120),
          raw_output: "Plan: #{add} to add, #{change} to change, #{destroy} to destroy.",
          created_at: check_time
        }
      when :error
        checks_data << {
          status: :error,
          add_count: 0,
          change_count: 0,
          destroy_count: 0,
          duration: rand(5..20),
          raw_output: "Error: Failed to refresh state. Check credentials.",
          created_at: check_time
        }
      end
    end
  end

  # Sort by created_at and insert with proper execution numbers
  # Skip retention limit callback for demo data
  checks_data.sort_by! { |c| c[:created_at] }

  DriftCheck.skip_callback(:create, :after, :enforce_retention_limit) if DriftCheck.respond_to?(:skip_callback)

  checks_data.each_with_index do |attrs, index|
    env.drift_checks.create!(attrs.merge(execution_number: index + 1))
  end

  DriftCheck.set_callback(:create, :after, :enforce_retention_limit) if DriftCheck.respond_to?(:set_callback)
end

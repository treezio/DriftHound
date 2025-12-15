# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Seed bulk projects and historical data for charts (75 projects, 30 days)"
    task bulk: :environment do
      puts "=" * 80
      puts "DriftHound Bulk Data Seeds"
      puts "=" * 80
      puts ""

      # Project name templates for realistic variety
      project_templates = [
        # Microservices
        { prefix: "", suffix: "-service", names: %w[user order inventory shipping billing notification analytics reporting search recommendation cache session messaging] },
        # Applications
        { prefix: "", suffix: "-app", names: %w[mobile web admin dashboard portal customer merchant partner internal employee] },
        # Infrastructure
        { prefix: "", suffix: "", names: %w[api-gateway load-balancer cdn-proxy data-pipeline etl-processor batch-worker queue-consumer event-broker] },
        # Platforms
        { prefix: "", suffix: "-platform", names: %w[data ml ai monitoring logging security identity compliance audit] },
        # Backend systems
        { prefix: "", suffix: "-backend", names: %w[core legacy main primary secondary] }
      ]

      # Environment configurations
      environment_configs = [
        { name: "Production", key: "production", weight: 3 },
        { name: "Staging", key: "staging", weight: 2 },
        { name: "Development", key: "development", weight: 1 },
        { name: "QA", key: "qa", weight: 1 },
        { name: "UAT", key: "uat", weight: 1 }
      ]

      # Track created projects to reach 75
      existing_count = Project.count
      target_count = 75
      projects_to_create = target_count - existing_count

      if projects_to_create > 0
        puts "Creating #{projects_to_create} additional projects..."
        puts ""

        created_names = Project.pluck(:name)
        project_index = 0

        # Flatten all possible project names
        all_project_names = []
        project_templates.each do |template|
          template[:names].each do |name|
            full_name = "#{template[:prefix]}#{name}#{template[:suffix]}"
            all_project_names << full_name unless created_names.include?(full_name)
          end
        end

        # Add numbered variants if we need more
        base_names = %w[service app platform system module component worker handler processor manager]
        teams = %w[alpha beta gamma delta epsilon zeta eta theta iota kappa lambda mu nu xi omicron]

        teams.each do |team|
          base_names.each do |base|
            name = "#{team}-#{base}"
            all_project_names << name unless created_names.include?(name)
          end
        end

        # Shuffle for variety
        all_project_names.shuffle!

        projects_to_create.times do |i|
          break if project_index >= all_project_names.length

          project_name = all_project_names[project_index]
          project_index += 1

          # Create project
          project = Project.create!(
            name: project_name,
            key: project_name.parameterize,
            repository: "https://github.com/acme/#{project_name.parameterize}"
          )

          # Randomly assign notification channel (70% chance)
          if rand < 0.7
            project.notification_channels.find_or_initialize_by(channel_type: "slack").update!(
              config: { "channel" => "##{project_name.parameterize}-alerts" },
              enabled: true
            )
          end

          # Create 1-3 environments per project
          num_environments = rand(1..3)
          selected_envs = environment_configs.sample(num_environments)

          selected_envs.each do |env_config|
            # Random status distribution: 60% ok, 25% drift, 10% error, 5% unknown
            status_roll = rand(100)
            status = case
            when status_roll < 60 then :ok
            when status_roll < 85 then :drift
            when status_roll < 95 then :error
            else :unknown
            end

            env = project.environments.create!(
              name: env_config[:name],
              key: env_config[:key],
              status: status,
              last_checked_at: rand(1..72).hours.ago,
              directory: "terraform/#{env_config[:key]}"
            )

            # Create a recent drift check for this environment
            case status
            when :ok
              env.drift_checks.create!(
                status: :ok,
                add_count: 0,
                change_count: 0,
                destroy_count: 0,
                duration: rand(20..120),
                raw_output: "No changes. Your infrastructure matches the configuration.",
                created_at: env.last_checked_at,
                execution_number: 1
              )
            when :drift
              add = rand(0..5)
              change = rand(1..8)
              destroy = rand(0..3)
              env.drift_checks.create!(
                status: :drift,
                add_count: add,
                change_count: change,
                destroy_count: destroy,
                duration: rand(30..150),
                raw_output: "Plan: #{add} to add, #{change} to change, #{destroy} to destroy.",
                created_at: env.last_checked_at,
                execution_number: 1
              )
            when :error
              env.drift_checks.create!(
                status: :error,
                add_count: 0,
                change_count: 0,
                destroy_count: 0,
                duration: rand(5..30),
                raw_output: [
                  "Error: Failed to refresh state",
                  "Error: Authentication failed",
                  "Error: Provider configuration error",
                  "Error: State lock timeout",
                  "Error: Invalid credentials",
                  "Error: Resource not found"
                ].sample,
                created_at: env.last_checked_at,
                execution_number: 1
              )
            end
          end

          # Progress indicator
          print "." if (i + 1) % 10 == 0
        end

        puts ""
        puts "✓ Created #{projects_to_create} additional projects"
      else
        puts "Already have #{existing_count} projects (target: #{target_count})"
      end

      puts ""
      puts "Total projects: #{Project.count}"
      puts "Total environments: #{Environment.count}"
      puts ""

      # Historical Data for Charts
      puts "=" * 80
      puts "Generating Historical Chart Data (30 days)"
      puts "=" * 80
      puts ""

      # Collect all environments for historical data generation
      all_environments = Environment.all.to_a

      puts "Generating historical checks data..."

      # Track historical checks per environment (env_id => array of check attributes)
      historical_checks_by_env = Hash.new { |h, k| h[k] = [] }

      # Generate check data for each day
      30.downto(1) do |days_ago|
        check_date = days_ago.days.ago

        all_environments.each do |env|
          # Skip some days randomly to simulate real-world patterns (not every env checked daily)
          next if rand < 0.3

          # Weight probabilities based on realistic scenarios
          # Most checks should be OK, with occasional drift and rare errors
          status_roll = rand(100)
          status = case
          when status_roll < 75 then :ok
          when status_roll < 92 then :drift
          else :error
          end

          # Generate realistic counts based on status
          case status
          when :ok
            add_count = 0
            change_count = 0
            destroy_count = 0
            output = "No changes. Your infrastructure matches the configuration."
          when :drift
            add_count = rand(0..3)
            change_count = rand(1..5)
            destroy_count = rand(0..2)
            output = "Plan: #{add_count} to add, #{change_count} to change, #{destroy_count} to destroy."
          when :error
            add_count = 0
            change_count = 0
            destroy_count = 0
            output = [ "Error: Failed to refresh state",
                       "Error: Authentication failed",
                       "Error: Provider configuration error",
                       "Error: State lock timeout" ].sample
          end

          # Store check attributes with calculated timestamp
          historical_checks_by_env[env.id] << {
            status: status,
            add_count: add_count,
            change_count: change_count,
            destroy_count: destroy_count,
            duration: rand(20..180),
            raw_output: output,
            created_at: check_date + rand(0..23).hours + rand(0..59).minutes
          }
        end

        # Progress indicator
        print "." if days_ago % 5 == 0
      end
      puts ""

      # Now insert checks in chronological order per environment
      # This ensures execution_number matches created_at order
      puts "Inserting checks with proper execution numbering..."

      all_environments.each do |env|
        checks_data = historical_checks_by_env[env.id]
        next if checks_data.empty?

        # Sort by created_at (oldest first)
        checks_data.sort_by! { |c| c[:created_at] }

        # Get current max execution_number for this environment
        current_max = env.drift_checks.maximum(:execution_number) || 0

        # Insert in chronological order with sequential execution numbers
        checks_data.each_with_index do |check_attrs, index|
          env.drift_checks.create!(
            check_attrs.merge(execution_number: current_max + index + 1)
          )
        end
      end

      puts "✓ Inserted historical checks"

      # Count generated historical checks
      historical_checks_count = DriftCheck.where("created_at < ?", 1.day.ago).count
      puts "✓ Generated #{historical_checks_count} historical drift checks"
      puts ""

      # Fix execution numbers to ensure chronological order
      puts "Fixing execution numbers to match chronological order..."

      Environment.find_each do |env|
        checks = env.drift_checks.order(:created_at).to_a
        next if checks.empty?

        # First, set all to negative IDs to avoid unique constraint conflicts
        checks.each do |check|
          check.update_column(:execution_number, -check.id)
        end

        # Now assign sequential numbers in chronological order
        checks.each_with_index do |check, index|
          check.update_column(:execution_number, index + 1)
        end
      end

      puts "✓ Execution numbers fixed for all environments"
      puts ""

      # Show distribution
      status_counts = DriftCheck.group(:status).count
      puts "Status distribution:"
      status_counts.each do |status, count|
        percentage = (count.to_f / DriftCheck.count * 100).round(1)
        puts "  - #{status}: #{count} (#{percentage}%)"
      end
      puts ""

      puts "=" * 80
      puts "Bulk Data Summary"
      puts "=" * 80
      puts "Projects: #{Project.count}"
      puts "Environments: #{Environment.count}"
      puts "Drift checks: #{DriftCheck.count}"
      puts "Notification channels: #{NotificationChannel.count}"
      puts "=" * 80
    end
  end
end

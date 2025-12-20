# Helper module for demo data generation
module DemoDataGenerator
  extend self

  def determine_status(in_drift:, drift_duration:, drift_probability:, error_probability:, is_production:)
    rand_value = rand

    # If currently in drift, higher chance of staying in drift (but it should resolve eventually)
    if in_drift
      # Drift resolution probability increases over time
      # Production resolves faster (more attention)
      resolution_base = is_production ? 0.4 : 0.25
      resolution_probability = resolution_base + (drift_duration * 0.1)

      if rand_value < resolution_probability
        :ok
      elsif rand_value < resolution_probability + error_probability
        :error
      else
        :drift
      end
    else
      # Normal state - check for new drift or error
      if rand_value < error_probability
        :error
      elsif rand_value < error_probability + drift_probability
        :drift
      else
        :ok
      end
    end
  end

  def generate_counts(status)
    case status
    when :ok
      { add: 0, change: 0, destroy: 0 }
    when :drift
      # Realistic drift patterns
      patterns = [
        { add: rand(1..5), change: 0, destroy: 0 },           # Resources to add
        { add: 0, change: rand(1..8), destroy: 0 },           # Resources to change
        { add: 0, change: 0, destroy: rand(1..3) },           # Resources to destroy
        { add: rand(1..3), change: rand(1..5), destroy: 0 },  # Mixed add/change
        { add: 0, change: rand(1..3), destroy: rand(1..2) },  # Mixed change/destroy
        { add: rand(1..2), change: rand(1..3), destroy: rand(1..2) }  # All types
      ]
      patterns.sample
    when :error
      { add: nil, change: nil, destroy: nil }
    else
      { add: 0, change: 0, destroy: 0 }
    end
  end

  def generate_raw_output(status, counts)
    case status
    when :ok
      <<~OUTPUT
        Running plan in ./environments/...

        No changes. Your infrastructure matches the configuration.

        Terraform has compared your real infrastructure against your configuration
        and found no differences, so no changes are needed.
      OUTPUT
    when :drift
      <<~OUTPUT
        Running plan in ./environments/...

        Terraform will perform the following actions:

        #{generate_drift_details(counts)}

        Plan: #{counts[:add] || 0} to add, #{counts[:change] || 0} to change, #{counts[:destroy] || 0} to destroy.
      OUTPUT
    when :error
      errors = [
        "Error: Failed to query available provider packages",
        "Error: Error acquiring the state lock",
        "Error: Invalid provider configuration",
        "Error: Error loading state: AccessDenied",
        "Error: Backend initialization required, please run 'terraform init'"
      ]
      <<~OUTPUT
        Running plan in ./environments/...

        #{errors.sample}

        This may be caused by a network issue or invalid credentials.
        Please check your configuration and try again.
      OUTPUT
    end
  end

  def generate_drift_details(counts)
    details = []

    if counts[:add] && counts[:add] > 0
      counts[:add].times do |i|
        resource_types = %w[random_id random_string random_integer random_uuid]
        details << "  # #{resource_types.sample}.resource_#{i} will be created"
      end
    end

    if counts[:change] && counts[:change] > 0
      counts[:change].times do |i|
        resource_types = %w[random_id random_string random_integer random_uuid]
        details << "  # #{resource_types.sample}.resource_#{i} will be updated in-place"
      end
    end

    if counts[:destroy] && counts[:destroy] > 0
      counts[:destroy].times do |i|
        resource_types = %w[random_id random_string random_integer random_uuid]
        details << "  # #{resource_types.sample}.resource_#{i} will be destroyed"
      end
    end

    details.join("\n")
  end
end

namespace :demo do
  desc "Backfill 90 days of realistic drift check data for demo purposes"
  task backfill: :environment do
    include DemoDataGenerator

    puts "Starting demo data backfill..."

    # Demo projects configuration matching drifthound-infra-demo
    projects_config = {
      "api-gateway" => {
        environments: %w[production staging],
        drift_probability: 0.08,  # 8% chance of drift
        error_probability: 0.02   # 2% chance of error
      },
      "auth-service" => {
        environments: %w[production],
        drift_probability: 0.05,
        error_probability: 0.01
      },
      "billing-platform" => {
        environments: %w[production staging],
        drift_probability: 0.15,  # Higher drift - billing changes often
        error_probability: 0.03
      },
      "data-pipeline" => {
        environments: %w[production],
        drift_probability: 0.10,
        error_probability: 0.05   # Higher error rate - complex system
      },
      "user-database" => {
        environments: %w[production staging development],
        drift_probability: 0.12,
        error_probability: 0.02
      }
    }

    days_to_backfill = 90
    checks_per_day = 4  # Simulating checks every 6 hours

    # Disable callbacks temporarily for performance
    DriftCheck.skip_callback(:create, :after, :update_environment_status)
    DriftCheck.skip_callback(:create, :after, :enforce_retention_limit)

    total_checks = 0

    projects_config.each do |project_key, config|
      # Find or create project
      project = Project.find_or_create_by!(key: project_key) do |p|
        p.name = project_key.titleize
        p.repository = "https://github.com/demo/#{project_key}"
        p.branch = "main"
      end
      puts "Project: #{project.name}"

      config[:environments].each do |env_key|
        # Find or create environment
        environment = Environment.find_or_create_by!(project: project, key: env_key) do |e|
          e.name = env_key.titleize
          e.directory = "./environments/#{env_key}/#{project_key}"
        end
        puts "  Environment: #{environment.name}"

        # Track drift state for realistic patterns
        in_drift = false
        drift_duration = 0
        execution_number = environment.drift_checks.maximum(:execution_number) || 0

        # Generate checks for each day
        days_to_backfill.downto(1) do |days_ago|
          checks_per_day.times do |check_index|
            execution_number += 1
            # Calculate timestamp (spread checks throughout the day)
            hours_offset = check_index * 6
            check_time = days_ago.days.ago.beginning_of_day + hours_offset.hours + rand(0..59).minutes

            # Determine status based on probabilities and current state
            status = DemoDataGenerator.determine_status(
              in_drift: in_drift,
              drift_duration: drift_duration,
              drift_probability: config[:drift_probability],
              error_probability: config[:error_probability],
              is_production: env_key == "production"
            )

            # Update drift tracking
            if status == :drift
              in_drift = true
              drift_duration += 1
            elsif status == :ok && in_drift
              in_drift = false
              drift_duration = 0
            end

            # Generate realistic counts
            counts = DemoDataGenerator.generate_counts(status)

            # Create the drift check
            DriftCheck.create!(
              environment: environment,
              status: status,
              execution_number: execution_number,
              add_count: counts[:add],
              change_count: counts[:change],
              destroy_count: counts[:destroy],
              duration: rand(5..120),  # 5 seconds to 2 minutes
              raw_output: DemoDataGenerator.generate_raw_output(status, counts),
              created_at: check_time,
              updated_at: check_time
            )

            total_checks += 1
          end
        end

        # Update environment to reflect latest status
        latest_check = environment.drift_checks.order(created_at: :desc).first
        if latest_check
          environment.update!(
            status: latest_check.status,
            last_checked_at: latest_check.created_at
          )
        end

        puts "    Created #{execution_number} checks"
      end
    end

    # Re-enable callbacks
    DriftCheck.set_callback(:create, :after, :update_environment_status)
    DriftCheck.set_callback(:create, :after, :enforce_retention_limit)

    puts "\nBackfill complete!"
    puts "Total drift checks created: #{total_checks}"
    puts "Projects: #{Project.count}"
    puts "Environments: #{Environment.count}"
  end

  desc "Clear all demo data (projects, environments, drift checks)"
  task clear: :environment do
    puts "Clearing all demo data..."

    DriftCheck.delete_all
    Environment.delete_all
    Project.delete_all

    puts "Done! All projects, environments, and drift checks have been removed."
  end
end

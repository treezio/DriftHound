# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Seed edge case data (long names, special characters, etc.)"
    task edge_cases: :environment do
      puts "=" * 80
      puts "DriftHound Edge Cases Seeds"
      puts "=" * 80
      puts ""

      # Edge Case 1: Long project and environment names (for testing UI overflow)
      puts "Edge Case 1: Long Names"
      puts "-" * 40

      project_long = Project.find_or_create_by!(key: "super-long-project-name-for-enterprise-infrastructure-management-system") do |p|
        p.name = "super-long-project-name-for-enterprise-infrastructure-management-system"
        p.repository = "https://github.com/acme-corporation/super-long-project-name-for-enterprise-infrastructure-management-system"
      end

      env_long = project_long.environments.find_or_create_by!(key: "production-us-east-1-primary-datacenter-cluster-a") do |e|
        e.name = "production-us-east-1-primary-datacenter-cluster-a"
        e.status = :ok
        e.directory = "terraform/environments/production/us-east-1/primary-datacenter/cluster-a"
      end
      env_long.update!(last_checked_at: 5.minutes.ago)

      max_exec = env_long.drift_checks.maximum(:execution_number) || 0
      env_long.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 120
        c.raw_output = "No changes. Infrastructure matches code."
        c.created_at = Time.current
      end

      puts "  Project: #{project_long.name}"
      puts "  Environment: #{env_long.name}"
      puts "  ✓ Created for testing long name overflow in UI"
      puts ""

      # Edge Case 2: Very long repository URL
      puts "Edge Case 2: Long Repository URL"
      puts "-" * 40

      project_long_repo = Project.find_or_create_by!(key: "long-repo-url-project") do |p|
        p.name = "long-repo-url-project"
        p.repository = "https://gitlab.internal.very-long-company-name.enterprise-solutions.io/organizations/infrastructure-team/terraform-modules/aws-networking-and-security-compliance-module-v2"
      end

      env_long_repo = project_long_repo.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :ok
        e.directory = "terraform/production"
      end
      env_long_repo.update!(last_checked_at: 15.minutes.ago)

      max_exec = env_long_repo.drift_checks.maximum(:execution_number) || 0
      env_long_repo.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 85
        c.raw_output = "No changes. Infrastructure matches code."
        c.created_at = Time.current
      end

      puts "  Repository: #{project_long_repo.repository}"
      puts "  ✓ Created for testing long URL handling"
      puts ""

      # Edge Case 3: Very long raw output (error messages)
      puts "Edge Case 3: Long Raw Output"
      puts "-" * 40

      project_long_output = Project.find_or_create_by!(key: "long-output-project") do |p|
        p.name = "long-output-project"
      end

      env_long_output = project_long_output.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :error
        e.directory = "terraform/production"
      end
      env_long_output.update!(last_checked_at: 10.minutes.ago)

      long_error_output = <<~OUTPUT
        Error: Error acquiring the state lock

        Error message: ConditionalCheckFailedException: The conditional request failed
        Lock Info:
          ID:        a1b2c3d4-e5f6-7890-abcd-ef1234567890
          Path:      s3://terraform-state-bucket/production/terraform.tfstate
          Operation: OperationTypeApply
          Who:       user@company.com
          Version:   1.5.7
          Created:   2024-01-15 10:30:00 UTC
          Info:

        Terraform acquires a state lock to protect the state from being written
        by multiple users at the same time. Please resolve the issue above and try
        again. For most commands, you can disable locking with the "-lock=false"
        flag, but this is not recommended.

        Stack trace:
          github.com/hashicorp/terraform/internal/states/statemgr.(*Locker).Lock
            /opt/teamcity-agent/work/terraform/internal/states/statemgr/locker.go:42
          github.com/hashicorp/terraform/internal/backend/remote-state/s3.(*Backend).Lock
            /opt/teamcity-agent/work/terraform/internal/backend/remote-state/s3/backend_state.go:126
          github.com/hashicorp/terraform/internal/backend.(*Local).Operation
            /opt/teamcity-agent/work/terraform/internal/backend/local/backend_local.go:193

        Additional context:
        - AWS Region: us-east-1
        - State File Size: 2.4 MB
        - Last Modified: 2024-01-15 10:25:00 UTC
        - DynamoDB Table: terraform-state-locks
        - Bucket: terraform-state-bucket

        Possible solutions:
        1. Check if another Terraform operation is in progress
        2. Verify AWS credentials have proper permissions
        3. Check DynamoDB table for stale locks
        4. Use 'terraform force-unlock LOCK_ID' if lock is stale
        5. Contact the lock owner to release the lock

        For more information, see:
        https://developer.hashicorp.com/terraform/language/state/locking
      OUTPUT

      max_exec = env_long_output.drift_checks.maximum(:execution_number) || 0
      env_long_output.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :error
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 5
        c.raw_output = long_error_output
        c.created_at = Time.current
      end

      puts "  Project: long-output-project"
      puts "  Output length: #{long_error_output.length} characters"
      puts "  ✓ Created for testing long raw output display"
      puts ""

      # Edge Case 4: High change counts
      puts "Edge Case 4: High Change Counts"
      puts "-" * 40

      project_high_counts = Project.find_or_create_by!(key: "high-change-counts") do |p|
        p.name = "high-change-counts"
      end

      env_high_counts = project_high_counts.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :drift
        e.directory = "terraform/production"
      end
      env_high_counts.update!(last_checked_at: 5.minutes.ago)

      max_exec = env_high_counts.drift_checks.maximum(:execution_number) || 0
      env_high_counts.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :drift
        c.add_count = 150
        c.change_count = 300
        c.destroy_count = 75
        c.duration = 450
        c.raw_output = "Plan: 150 to add, 300 to change, 75 to destroy.\n\nThis is a major infrastructure change that requires careful review."
        c.created_at = Time.current
      end

      puts "  Project: high-change-counts"
      puts "  Changes: +150, ~300, -75"
      puts "  ✓ Created for testing high number display"
      puts ""

      # Edge Case 5: Zero-length duration (instant check)
      puts "Edge Case 5: Zero Duration"
      puts "-" * 40

      project_zero_duration = Project.find_or_create_by!(key: "zero-duration-project") do |p|
        p.name = "zero-duration-project"
      end

      env_zero_duration = project_zero_duration.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :ok
        e.directory = "terraform/production"
      end
      env_zero_duration.update!(last_checked_at: 2.minutes.ago)

      max_exec = env_zero_duration.drift_checks.maximum(:execution_number) || 0
      env_zero_duration.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 0
        c.raw_output = "No changes. Infrastructure matches code."
        c.created_at = Time.current
      end

      puts "  Project: zero-duration-project"
      puts "  Duration: 0 seconds"
      puts "  ✓ Created for testing zero duration display"
      puts ""

      # Edge Case 6: Very long duration
      puts "Edge Case 6: Very Long Duration"
      puts "-" * 40

      project_long_duration = Project.find_or_create_by!(key: "long-duration-project") do |p|
        p.name = "long-duration-project"
      end

      env_long_duration = project_long_duration.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :ok
        e.directory = "terraform/production"
      end
      env_long_duration.update!(last_checked_at: 3.hours.ago)

      max_exec = env_long_duration.drift_checks.maximum(:execution_number) || 0
      env_long_duration.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 7200 # 2 hours in seconds
        c.raw_output = "No changes. Infrastructure matches code. (Large state file with 5000+ resources)"
        c.created_at = Time.current
      end

      puts "  Project: long-duration-project"
      puts "  Duration: 7200 seconds (2 hours)"
      puts "  ✓ Created for testing long duration display"
      puts ""

      # Edge Case 7: Multiple environments with same name in different projects
      puts "Edge Case 7: Duplicate Environment Names"
      puts "-" * 40

      %w[project-alpha project-beta project-gamma].each do |proj_name|
        project = Project.find_or_create_by!(key: proj_name) do |p|
          p.name = proj_name
        end

        env = project.environments.find_or_create_by!(key: "production") do |e|
          e.name = "Production"
          e.status = :ok
          e.directory = "terraform/production"
        end
        env.update!(last_checked_at: rand(1..60).minutes.ago)

        max_exec = env.drift_checks.maximum(:execution_number) || 0
        env.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
          c.status = :ok
          c.add_count = 0
          c.change_count = 0
          c.destroy_count = 0
          c.duration = rand(20..60)
          c.raw_output = "No changes. Infrastructure matches code."
          c.created_at = Time.current
        end

        puts "  #{proj_name}/production ✓"
      end
      puts "  ✓ Created for testing disambiguation of same-named environments"
      puts ""

      # Edge Case 8: Nil/null values where allowed
      puts "Edge Case 8: Nil Values"
      puts "-" * 40

      project_nil = Project.find_or_create_by!(key: "nil-values-project") do |p|
        p.name = "nil-values-project"
        p.repository = nil # No repository set
      end

      env_nil = project_nil.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :drift
        e.directory = nil # No directory set
      end
      env_nil.update!(last_checked_at: 20.minutes.ago)

      max_exec = env_nil.drift_checks.maximum(:execution_number) || 0
      env_nil.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :drift
        c.add_count = nil # Nil counts
        c.change_count = nil
        c.destroy_count = nil
        c.duration = nil
        c.raw_output = nil
        c.created_at = Time.current
      end

      puts "  Project: nil-values-project"
      puts "  Repository: nil, Directory: nil, Counts: nil"
      puts "  ✓ Created for testing nil value handling"
      puts ""

      # Edge Case 9: Directory paths with ./ prefix
      puts "Edge Case 9: Directory Paths with ./ Prefix"
      puts "-" * 40

      project_dotslash = Project.find_or_create_by!(key: "dotslash-directory-project") do |p|
        p.name = "dotslash-directory-project"
        p.repository = "https://github.com/acme/infrastructure"
      end

      env_dotslash = project_dotslash.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :ok
        e.directory = "./automation/terraform/environments/production"
      end
      env_dotslash.update!(last_checked_at: 10.minutes.ago)

      max_exec = env_dotslash.drift_checks.maximum(:execution_number) || 0
      env_dotslash.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 45
        c.raw_output = "No changes. Infrastructure matches code."
        c.created_at = Time.current
      end

      puts "  Project: dotslash-directory-project"
      puts "  Directory input: ./automation/terraform/environments/production"
      puts "  Directory stored: #{env_dotslash.reload.directory}"
      puts "  ✓ Created for testing ./ prefix stripping"
      puts ""

      # Edge Case 10: Repository URL with embedded credentials (should be sanitized)
      puts "Edge Case 10: Repository URL with Credentials"
      puts "-" * 40

      project_creds = Project.find_or_create_by!(key: "credentials-url-project") do |p|
        p.name = "credentials-url-project"
        # This should be sanitized by the model's before_save callback
        p.repository = "https://x-access-token:ghp_secret123@github.com/acme/private-repo"
      end

      env_creds = project_creds.environments.find_or_create_by!(key: "production") do |e|
        e.name = "Production"
        e.status = :ok
        e.directory = "terraform/production"
      end
      env_creds.update!(last_checked_at: 5.minutes.ago)

      max_exec = env_creds.drift_checks.maximum(:execution_number) || 0
      env_creds.drift_checks.find_or_create_by!(execution_number: max_exec + 1) do |c|
        c.status = :ok
        c.add_count = 0
        c.change_count = 0
        c.destroy_count = 0
        c.duration = 30
        c.raw_output = "No changes. Infrastructure matches code."
        c.created_at = Time.current
      end

      # Verify sanitization worked
      project_creds.reload
      sanitized = !project_creds.repository.include?("@")
      puts "  Project: credentials-url-project"
      puts "  Original: https://x-access-token:ghp_***@github.com/acme/private-repo"
      puts "  Sanitized: #{project_creds.repository}"
      puts "  ✓ #{sanitized ? 'Credentials removed successfully' : 'WARNING: Credentials NOT removed!'}"
      puts ""

      # Summary
      puts "=" * 80
      puts "Edge Cases Summary"
      puts "=" * 80
      puts ""
      puts "Created edge case scenarios:"
      puts "  1. Long project/environment names"
      puts "  2. Long repository URL"
      puts "  3. Long raw output (error messages)"
      puts "  4. High change counts (+150, ~300, -75)"
      puts "  5. Zero duration check"
      puts "  6. Very long duration (2 hours)"
      puts "  7. Duplicate environment names across projects"
      puts "  8. Nil/null values"
      puts "  9. Directory paths with ./ prefix (sanitization test)"
      puts "  10. Repository URL with credentials (sanitization test)"
      puts ""
      puts "These scenarios help test UI overflow handling, data display,"
      puts "credential sanitization, and edge case resilience in the application."
      puts "=" * 80
    end
  end
end

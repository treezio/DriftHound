# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Run all development seed tasks (notifications + edge_cases + bulk)"
    task all: :environment do
      puts "=" * 80
      puts "Running All Development Seed Tasks"
      puts "=" * 80
      puts ""
      puts "Note: This task adds data to the existing database."
      puts "      Use 'bin/rails db:seed:reset' for a fresh start."
      puts ""

      Rake::Task["db:seed:notifications"].invoke
      puts ""

      Rake::Task["db:seed:edge_cases"].invoke
      puts ""

      Rake::Task["db:seed:bulk"].invoke
      puts ""

      puts "=" * 80
      puts "All Seed Tasks Complete"
      puts "=" * 80
      puts ""
      puts "Summary:"
      puts "  Projects: #{Project.count}"
      puts "  Environments: #{Environment.count}"
      puts "  Drift checks: #{DriftCheck.count}"
      puts "  Notification channels: #{NotificationChannel.count}"
      puts "=" * 80
    end

    desc "Clear all seed data (destructive)"
    task clear: :environment do
      puts "=" * 80
      puts "Clearing All Seed Data"
      puts "=" * 80
      puts ""

      print "Deleting drift checks... "
      count = DriftCheck.count
      DriftCheck.delete_all
      puts "#{count} deleted"

      print "Deleting notification states... "
      count = NotificationState.count
      NotificationState.delete_all
      puts "#{count} deleted"

      print "Deleting environments... "
      count = Environment.count
      Environment.delete_all
      puts "#{count} deleted"

      print "Deleting projects... "
      count = Project.count
      Project.delete_all
      puts "#{count} deleted"

      print "Deleting API tokens... "
      count = ApiToken.count
      ApiToken.delete_all
      puts "#{count} deleted"

      print "Deleting users... "
      count = User.count
      User.delete_all
      puts "#{count} deleted"

      puts ""
      puts "✓ All data cleared"
      puts "=" * 80
    end

    desc "Reset and reseed for development (clear + create admin + seed all)"
    task reset: :environment do
      Rake::Task["db:seed:clear"].invoke
      puts ""

      # Create admin user
      admin_email = ENV.fetch("ADMIN_EMAIL", "admin")
      admin_password = ENV.fetch("ADMIN_PASSWORD", "changeme")
      User.create!(email: admin_email, password: admin_password, admin: true)
      puts "✓ Admin user created: #{admin_email} / #{admin_password}"
      puts ""

      # Create API token
      api_token = ApiToken.create!(name: "default-token")
      puts "✓ API Token created: #{api_token.token}"
      puts ""

      Rake::Task["db:seed:all"].invoke

      puts ""
      puts "Login credentials: #{admin_email} / #{admin_password}"
    end
  end
end

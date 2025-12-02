# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
#
# Clear existing data
DriftCheck.delete_all
Environment.delete_all
Project.delete_all
ApiToken.delete_all

ApiToken.create!(name: "default-token")
# Print token for reference
puts "API Token: #{ApiToken.first.token}"

# Example projects and environments
data = [
  {
    name: "payment-service",
    key: "payment-service",
    environments: [
      { name: "Production", key: "production", status: :ok },
      { name: "Staging", key: "staging", status: :drift },
      { name: "Dev", key: "dev", status: :unknown }
    ]
  },
  {
    name: "user-api",
    key: "user-api",
    environments: [
      { name: "Production", key: "production", status: :ok },
      { name: "QA", key: "qa", status: :error }
    ]
  },
  {
    name: "analytics",
    key: "analytics",
    environments: [
      { name: "Prod", key: "prod", status: :ok }
    ]
  }
]

# Seed projects, environments, and drift checks
data.each do |proj|
  project = Project.create!(name: proj[:name], key: proj[:key])
  proj[:environments].each do |env|
    environment = project.environments.create!(name: env[:name], key: env[:key], status: env[:status], last_checked_at: rand(1..10).days.ago)
    # Add 3 drift checks per environment
    3.times do |i|
      status = [ :ok, :drift, :error, :unknown ].sample
      environment.drift_checks.create!(
        status: status,
        add_count: rand(0..3),
        change_count: rand(0..2),
        destroy_count: rand(0..1),
        duration: rand(10..120),
        raw_output: "Terraform plan output ##{i+1} for #{environment.name} (#{status})",
        created_at: (3-i).days.ago, # oldest gets 1, newest gets 3
        execution_number: i+1
      )
    end
  end
end

puts "Seeded #{Project.count} projects, #{Environment.count} environments, #{DriftCheck.count} drift checks."

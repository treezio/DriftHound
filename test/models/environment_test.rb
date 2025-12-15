require "test_helper"

class EnvironmentTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
  end

  test "requires name" do
    environment = Environment.new(project: @project, key: "production")
    assert_not environment.valid?
    assert_includes environment.errors[:name], "can't be blank"
  end

  test "requires key" do
    environment = Environment.new(project: @project, name: "Production")
    assert_not environment.valid?
    assert_includes environment.errors[:key], "can't be blank"
  end

  test "requires project" do
    environment = Environment.new(name: "Production", key: "production")
    assert_not environment.valid?
    assert_includes environment.errors[:project], "must exist"
  end

  test "key must be unique within project" do
    @project.environments.create!(name: "Production", key: "production")
    duplicate = @project.environments.new(name: "Prod", key: "production")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "same key can exist in different projects" do
    other_project = Project.create!(name: "Other", key: "other-project")

    @project.environments.create!(name: "Production", key: "production")
    other_env = other_project.environments.new(name: "Production", key: "production")

    assert other_env.valid?
  end

  test "key format only allows alphanumeric, dashes, and underscores" do
    valid_keys = %w[production staging my-env my_env Prod123]
    invalid_keys = [ "my env", "my.env", "my/env", "my@env" ]

    valid_keys.each do |key|
      environment = Environment.new(project: @project, name: "Test", key: key)
      environment.valid?
      assert_not_includes environment.errors[:key], "only allows alphanumeric characters, dashes, and underscores"
    end

    invalid_keys.each do |key|
      environment = Environment.new(project: @project, name: "Test", key: key)
      assert_not environment.valid?
      assert_includes environment.errors[:key], "only allows alphanumeric characters, dashes, and underscores"
    end
  end

  test "status enum values" do
    environment = @project.environments.create!(name: "Test", key: "test")

    assert environment.unknown?
    environment.ok!
    assert environment.ok?
    environment.drift!
    assert environment.drift?
    environment.error!
    assert environment.error?
  end

  test "find_or_create_by_key creates new environment with titleized name" do
    assert_difference "Environment.count", 1 do
      environment = Environment.find_or_create_by_key(@project, "my-staging-env")
      assert_equal "my-staging-env", environment.key
      assert_equal "My Staging Env", environment.name
    end
  end

  test "find_or_create_by_key returns existing environment" do
    existing = @project.environments.create!(name: "Existing", key: "existing-env")

    assert_no_difference "Environment.count" do
      found = Environment.find_or_create_by_key(@project, "existing-env")
      assert_equal existing.id, found.id
      assert_equal "Existing", found.name
    end
  end

  test "has many drift_checks" do
    environment = @project.environments.create!(name: "Test", key: "test")
    environment.drift_checks.create!(status: :ok)
    environment.drift_checks.create!(status: :drift)

    assert_equal 2, environment.drift_checks.count
  end

  test "destroying environment destroys associated drift_checks" do
    environment = @project.environments.create!(name: "Test", key: "test")
    environment.drift_checks.create!(status: :ok)
    environment.drift_checks.create!(status: :drift)

    assert_difference "DriftCheck.count", -2 do
      environment.destroy
    end
  end

  test "sanitizes directory path with single ./ prefix on create" do
    environment = @project.environments.create!(
      name: "Production",
      key: "prod-sanitize",
      directory: "./automation/terraform/production"
    )

    assert_equal "automation/terraform/production", environment.directory
  end

  test "sanitizes directory path with multiple ./ prefix on create" do
    environment = @project.environments.create!(
      name: "Production",
      key: "prod-double-dot",
      directory: "././automation/terraform/production"
    )

    assert_equal "automation/terraform/production", environment.directory
  end

  test "sanitizes directory path on update" do
    environment = @project.environments.create!(name: "Production", key: "prod-update")
    environment.update!(directory: "./path/to/terraform")

    assert_equal "path/to/terraform", environment.directory
  end

  test "leaves clean directory paths unchanged" do
    environment = @project.environments.create!(
      name: "Production",
      key: "prod-clean",
      directory: "terraform/production"
    )

    assert_equal "terraform/production", environment.directory
  end

  test "handles nil directory" do
    environment = @project.environments.create!(name: "Production", key: "prod-nil", directory: nil)
    assert_nil environment.directory
  end
end

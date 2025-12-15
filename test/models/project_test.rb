require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "requires name" do
    project = Project.new(key: "test-project")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "requires key" do
    project = Project.new(name: "Test Project")
    assert_not project.valid?
    assert_includes project.errors[:key], "can't be blank"
  end

  test "key must be unique" do
    Project.create!(name: "First", key: "unique-key")
    duplicate = Project.new(name: "Second", key: "unique-key")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:key], "has already been taken"
  end

  test "key format only allows alphanumeric, dashes, and underscores" do
    valid_keys = %w[my-project my_project MyProject project123]
    invalid_keys = [ "my project", "my.project", "my/project", "my@project" ]

    valid_keys.each do |key|
      project = Project.new(name: "Test", key: key)
      project.valid?
      assert_not_includes project.errors[:key], "only allows alphanumeric characters, dashes, and underscores"
    end

    invalid_keys.each do |key|
      project = Project.new(name: "Test", key: key)
      assert_not project.valid?
      assert_includes project.errors[:key], "only allows alphanumeric characters, dashes, and underscores"
    end
  end

  test "find_or_create_by_key creates new project with key as name" do
    assert_difference "Project.count", 1 do
      project = Project.find_or_create_by_key("my-infra-project")
      assert_equal "my-infra-project", project.key
      assert_equal "my-infra-project", project.name
    end
  end

  test "find_or_create_by_key returns existing project" do
    existing = Project.create!(name: "Existing", key: "existing-project")

    assert_no_difference "Project.count" do
      found = Project.find_or_create_by_key("existing-project")
      assert_equal existing.id, found.id
      assert_equal "Existing", found.name
    end
  end

  test "has many environments" do
    project = Project.create!(name: "Test", key: "test-project")
    project.environments.create!(name: "Production", key: "production")
    project.environments.create!(name: "Staging", key: "staging")

    assert_equal 2, project.environments.count
  end

  test "has many drift_checks through environments" do
    project = Project.create!(name: "Test", key: "test-project")
    env = project.environments.create!(name: "Production", key: "production")
    env.drift_checks.create!(status: :ok)
    env.drift_checks.create!(status: :drift)

    assert_equal 2, project.drift_checks.count
  end

  test "destroying project destroys associated environments and drift_checks" do
    project = Project.create!(name: "Test", key: "test-project")
    env = project.environments.create!(name: "Production", key: "production")
    env.drift_checks.create!(status: :ok)
    env.drift_checks.create!(status: :drift)

    assert_difference "Environment.count", -1 do
      assert_difference "DriftCheck.count", -2 do
        project.destroy
      end
    end
  end

  test "aggregated_status returns unknown when no environments" do
    project = Project.create!(name: "Test", key: "test-project")
    assert_equal "unknown", project.aggregated_status
  end

  test "aggregated_status returns error if any environment has error" do
    project = Project.create!(name: "Test", key: "test-project")
    project.environments.create!(name: "Production", key: "production", status: :ok)
    project.environments.create!(name: "Staging", key: "staging", status: :error)

    assert_equal "error", project.aggregated_status
  end

  test "aggregated_status returns drift if any environment has drift" do
    project = Project.create!(name: "Test", key: "test-project")
    project.environments.create!(name: "Production", key: "production", status: :ok)
    project.environments.create!(name: "Staging", key: "staging", status: :drift)

    assert_equal "drift", project.aggregated_status
  end

  test "aggregated_status returns ok when all environments are ok" do
    project = Project.create!(name: "Test", key: "test-project")
    project.environments.create!(name: "Production", key: "production", status: :ok)
    project.environments.create!(name: "Staging", key: "staging", status: :ok)

    assert_equal "ok", project.aggregated_status
  end

  test "last_checked_at returns most recent environment check time" do
    project = Project.create!(name: "Test", key: "test-project")
    project.environments.create!(name: "Production", key: "production", last_checked_at: 2.hours.ago)
    project.environments.create!(name: "Staging", key: "staging", last_checked_at: 1.hour.ago)

    assert_in_delta 1.hour.ago, project.last_checked_at, 1.second
  end

  test "sanitizes repository URL with embedded credentials on create" do
    project = Project.create!(
      name: "Test",
      key: "test-sanitize",
      repository: "https://x-access-token:ghp_secret123@github.com/org/repo"
    )

    assert_equal "https://github.com/org/repo", project.repository
  end

  test "sanitizes repository URL with embedded credentials on update" do
    project = Project.create!(name: "Test", key: "test-sanitize-update")
    project.update!(repository: "https://user:password@gitlab.com/org/repo.git")

    assert_equal "https://gitlab.com/org/repo.git", project.repository
  end

  test "leaves clean repository URLs unchanged" do
    project = Project.create!(
      name: "Test",
      key: "test-clean-url",
      repository: "https://github.com/org/repo"
    )

    assert_equal "https://github.com/org/repo", project.repository
  end

  test "handles nil repository" do
    project = Project.create!(name: "Test", key: "test-nil-repo", repository: nil)
    assert_nil project.repository
  end
end

require "test_helper"

class DriftCheckTest < ActiveSupport::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production")
  end

  test "requires status" do
    drift_check = DriftCheck.new(environment: @environment)
    assert_not drift_check.valid?
    assert_includes drift_check.errors[:status], "can't be blank"
  end

  test "requires environment" do
    drift_check = DriftCheck.new(status: :ok)
    assert_not drift_check.valid?
    assert_includes drift_check.errors[:environment], "must exist"
  end

  test "status enum values" do
    drift_check = @environment.drift_checks.create!(status: :unknown)
    assert drift_check.unknown?

    drift_check.ok!
    assert drift_check.ok?

    drift_check.drift!
    assert drift_check.drift?

    drift_check.error!
    assert drift_check.error?
  end

  test "stores add_count, change_count, destroy_count" do
    drift_check = @environment.drift_checks.create!(
      status: :drift,
      add_count: 5,
      change_count: 3,
      destroy_count: 2
    )

    assert_equal 5, drift_check.add_count
    assert_equal 3, drift_check.change_count
    assert_equal 2, drift_check.destroy_count
  end

  test "stores raw_output" do
    raw = "Plan: 5 to add, 3 to change, 2 to destroy."
    drift_check = @environment.drift_checks.create!(status: :drift, raw_output: raw)

    assert_equal raw, drift_check.raw_output
  end

  test "updates environment status after creation" do
    assert @environment.unknown?

    @environment.drift_checks.create!(status: :ok)
    @environment.reload
    assert @environment.ok?

    @environment.drift_checks.create!(status: :drift)
    @environment.reload
    assert @environment.drift?
  end

  test "updates environment last_checked_at after creation" do
    assert_nil @environment.last_checked_at

    freeze_time do
      @environment.drift_checks.create!(status: :ok)
      @environment.reload
      assert_equal Time.current, @environment.last_checked_at
    end
  end

  test "enforces retention limit of 10 checks per environment" do
    # Create 10 checks
    10.times do |i|
      @environment.drift_checks.create!(status: :ok, created_at: i.hours.ago)
    end

    assert_equal 10, @environment.drift_checks.count

    # Create 11th check - oldest should be deleted
    @environment.drift_checks.create!(status: :drift)

    assert_equal 10, @environment.drift_checks.count
    assert @environment.drift_checks.order(created_at: :desc).first.drift?
  end

  test "retention limit only affects same environment" do
    other_environment = @project.environments.create!(name: "Staging", key: "staging")

    10.times { @environment.drift_checks.create!(status: :ok) }
    5.times { other_environment.drift_checks.create!(status: :ok) }

    @environment.drift_checks.create!(status: :drift)

    assert_equal 10, @environment.drift_checks.count
    assert_equal 5, other_environment.drift_checks.count
  end

  test "delegates project to environment" do
    drift_check = @environment.drift_checks.create!(status: :ok)
    assert_equal @project, drift_check.project
  end
end

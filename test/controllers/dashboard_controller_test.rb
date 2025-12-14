require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows dashboard" do
    get root_path
    assert_response :success
    assert_select "h1", "DriftHound"
  end

  test "shows empty state when no projects exist" do
    Project.destroy_all
    get root_path
    assert_response :success
    assert_select ".empty-state"
  end


  test "shows dashboard with projects" do
    project = Project.create!(name: "Project", key: "project")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    # Simulate a drift check so last_check_status is set
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Plan: 0 to add, 0 to change, 0 to destroy.")
    get root_path
    assert_response :success
    assert_select ".project-env-row"
    assert_select ".col-project", /Project/
  end

  test "shows status counts correctly" do
    Project.destroy_all
    ok_project = Project.create!(name: "OK Project", key: "ok-project")
    drift_project = Project.create!(name: "Drift Project", key: "drift-project")
    error_project = Project.create!(name: "Error Project", key: "error-project")
    ok_env = ok_project.environments.create!(name: "Prod", key: "prod", status: :ok)
    drift_env = drift_project.environments.create!(name: "Prod", key: "prod", status: :drift)
    error_env = error_project.environments.create!(name: "Prod", key: "prod", status: :error)
    ok_env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Plan: 0 to add, 0 to change, 0 to destroy.")
    drift_env.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Plan: 1 to add, 0 to change, 0 to destroy.")
    error_env.drift_checks.create!(status: :error, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Error: something went wrong.")

    get root_path
    assert_response :success
    assert_select ".status-badge.status-ok .count", "1"
    assert_select ".status-badge.status-drift .count", "1"
    assert_select ".status-badge.status-error .count", "1"
  end

  # ===== Chart Data Tests =====

  test "assigns chart data for charts view" do
    Project.destroy_all
    project = Project.create!(name: "Chart Test Project", key: "chart-test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    env.drift_checks.create!(
      status: :ok,
      add_count: 1,
      change_count: 2,
      destroy_count: 0,
      duration: 5.5,
      raw_output: "Plan: 1 to add, 2 to change, 0 to destroy."
    )

    get root_path
    assert_response :success

    # Verify chart data is assigned
    assert assigns(:drift_chart_data).present?, "drift_chart_data should be assigned"
    assert assigns(:status_distribution_data).present?, "status_distribution_data should be assigned"
    assert assigns(:checks_per_project_data).present?, "checks_per_project_data should be assigned"
    assert assigns(:weekly_trend_data).present?, "weekly_trend_data should be assigned"
    assert assigns(:environment_health_data).present?, "environment_health_data should be assigned"
    assert assigns(:check_duration_data).present?, "check_duration_data should be assigned"
    assert assigns(:resource_changes_data).present?, "resource_changes_data should be assigned"
    assert assigns(:drift_rate_data).present?, "drift_rate_data should be assigned"
    assert assigns(:check_volume_data).present?, "check_volume_data should be assigned"
    assert assigns(:top_drifting_data).present?, "top_drifting_data should be assigned"
    assert assigns(:change_impact_data).present?, "change_impact_data should be assigned"
    assert assigns(:stability_score_data).present?, "stability_score_data should be assigned"
  end

  test "drift_chart_data has correct structure" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Staging", key: "staging", status: :drift)
    env.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Plan: 1 to add.")

    get root_path
    data = assigns(:drift_chart_data)

    assert data[:dates].is_a?(Array), "dates should be an array"
    assert_equal 31, data[:dates].length, "should have 31 days of date labels"

    assert data[:all].is_a?(Hash), "all should be a hash"
    assert data[:all][:drift].is_a?(Array), "all[:drift] should be an array"
    assert data[:all][:error].is_a?(Array), "all[:error] should be an array"
    assert data[:all][:ok].is_a?(Array), "all[:ok] should be an array"

    assert data[:by_environment].is_a?(Hash), "by_environment should be a hash"
    assert data[:by_environment]["Staging"].present?, "should have Staging environment data"
  end

  test "status_distribution_data has correct structure" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)
    env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "No changes.")

    get root_path
    data = assigns(:status_distribution_data)

    assert data[:all].is_a?(Hash), "all should be a hash"
    assert data[:all].key?(:ok), "all should have ok key"
    assert data[:all].key?(:drift), "all should have drift key"
    assert data[:all].key?(:error), "all should have error key"

    assert data[:by_environment].is_a?(Hash), "by_environment should be a hash"
  end

  test "status_distribution_data counts checks correctly" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)

    # Create multiple checks with different statuses
    3.times { env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK") }
    2.times { env.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Drift") }
    1.times { env.drift_checks.create!(status: :error, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "Error") }

    get root_path
    data = assigns(:status_distribution_data)

    assert_equal 3, data[:all][:ok], "should count 3 OK checks"
    assert_equal 2, data[:all][:drift], "should count 2 drift checks"
    assert_equal 1, data[:all][:error], "should count 1 error check"
  end

  test "environment_health_data has correct structure" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    prod = project.environments.create!(name: "Production", key: "production", status: :ok)
    staging = project.environments.create!(name: "Staging", key: "staging", status: :drift)
    prod.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")
    staging.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Drift")

    get root_path
    data = assigns(:environment_health_data)

    assert data[:labels].is_a?(Array), "labels should be an array"
    assert data[:ok].is_a?(Array), "ok should be an array"
    assert data[:drift].is_a?(Array), "drift should be an array"
    assert data[:error].is_a?(Array), "error should be an array"
    assert_equal data[:labels].length, data[:ok].length, "arrays should have same length"
  end

  test "resource_changes_data tracks add/change/destroy counts" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :drift)
    env.drift_checks.create!(status: :drift, add_count: 5, change_count: 3, destroy_count: 2, raw_output: "Changes")

    get root_path
    data = assigns(:resource_changes_data)

    assert data[:labels].is_a?(Array), "labels should be an array"
    assert data[:all][:adds].is_a?(Array), "adds should be an array"
    assert data[:all][:changes].is_a?(Array), "changes should be an array"
    assert data[:all][:destroys].is_a?(Array), "destroys should be an array"

    # Today's counts should include our check
    assert data[:all][:adds].sum >= 5, "should include add counts"
    assert data[:all][:changes].sum >= 3, "should include change counts"
    assert data[:all][:destroys].sum >= 2, "should include destroy counts"
  end

  test "stability_score_data calculates score correctly" do
    Project.destroy_all
    project = Project.create!(name: "Stable Project", key: "stable")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)

    # Create 7 consecutive OK checks (should be stable_7plus)
    7.times do |i|
      env.drift_checks.create!(
        status: :ok,
        add_count: 0,
        change_count: 0,
        destroy_count: 0,
        raw_output: "OK",
        created_at: i.days.ago
      )
    end

    get root_path
    data = assigns(:stability_score_data)

    assert data[:score].is_a?(Numeric), "score should be numeric"
    assert data[:score] >= 0 && data[:score] <= 100, "score should be between 0 and 100"
    assert data[:breakdown].is_a?(Hash), "breakdown should be a hash"
    assert data[:breakdown][:stable_7plus] >= 1, "should have at least 1 stable environment"
  end

  test "top_drifting_data identifies projects with most drift" do
    Project.destroy_all

    # Create a project with high drift rate
    drifty = Project.create!(name: "Drifty Project", key: "drifty")
    drifty_env = drifty.environments.create!(name: "Production", key: "production", status: :drift)
    5.times { drifty_env.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Drift") }

    # Create a project with low drift rate
    stable = Project.create!(name: "Stable Project", key: "stable")
    stable_env = stable.environments.create!(name: "Production", key: "production", status: :ok)
    5.times { stable_env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK") }

    get root_path
    data = assigns(:top_drifting_data)

    assert data[:labels].is_a?(Array), "labels should be an array"
    assert data[:all][:rates].is_a?(Array), "rates should be an array"
    assert data[:all][:counts].is_a?(Array), "counts should be an array"

    # Drifty project should appear first (100% drift rate)
    if data[:labels].any?
      assert_equal "Drifty Project", data[:labels].first, "highest drift project should be first"
      assert_equal 100.0, data[:all][:rates].first, "drift rate should be 100%"
    end
  end

  test "check_volume_data tracks daily check counts" do
    Project.destroy_all
    project = Project.create!(name: "Test Project", key: "test")
    env = project.environments.create!(name: "Production", key: "production", status: :ok)

    # Create checks today
    3.times { env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK") }

    get root_path
    data = assigns(:check_volume_data)

    assert data[:labels].is_a?(Array), "labels should be an array"
    assert data[:all].is_a?(Array), "all should be an array"
    assert_equal 15, data[:all].length, "should have 15 days of data"

    # Today's count should include our checks
    assert data[:all].last >= 3, "today should have at least 3 checks"
  end

  test "chart data includes per-environment filtering" do
    Project.destroy_all
    project = Project.create!(name: "Multi Env Project", key: "multi-env")
    prod = project.environments.create!(name: "Production", key: "production", status: :ok)
    staging = project.environments.create!(name: "Staging", key: "staging", status: :drift)

    prod.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")
    staging.drift_checks.create!(status: :drift, add_count: 1, change_count: 0, destroy_count: 0, raw_output: "Drift")

    get root_path

    # Verify all chart data has by_environment filtering
    assert assigns(:drift_chart_data)[:by_environment].key?("Production"), "drift_chart_data should have Production env"
    assert assigns(:drift_chart_data)[:by_environment].key?("Staging"), "drift_chart_data should have Staging env"

    assert assigns(:status_distribution_data)[:by_environment].key?("Production"), "status_distribution_data should have Production env"
    assert assigns(:check_volume_data)[:by_environment].key?("Production"), "check_volume_data should have Production env"
  end
end

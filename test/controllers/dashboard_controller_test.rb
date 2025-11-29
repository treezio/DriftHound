require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "shows dashboard" do
    get root_path
    assert_response :success
    assert_select "h1", "🐕 DriftHound"
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
end

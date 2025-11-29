require "application_system_test_case"

class DashboardViewsTest < ApplicationSystemTestCase
  def setup
    @project = Project.create!(name: "ViewTest Project", key: "viewtest-project")
    @env = @project.environments.create!(name: "Production", key: "production", status: :drift)
    @env.drift_checks.create!(status: :drift, add_count: 2, change_count: 1, destroy_count: 0, raw_output: "Plan: 2 to add, 1 to change, 0 to destroy.")
  end

  test "dashboard displays project and environment" do
    visit root_path
    assert_selector ".project-env-row", text: "ViewTest Project"
    assert_selector ".col-environment", text: "Production"
    assert_selector ".status-text--drift", text: "DRIFT"
  end

  test "project details page displays environments" do
    visit project_path(@project.key)
    assert_selector ".environment-row", text: "Production"
    assert_selector ".status-text--drift", text: "DRIFT"
  end

  test "environment details page displays drift check" do
    visit project_environment_path(@project.key, @env.key)
    assert_selector ".check-row"
    assert_selector ".status-text--drift", text: "DRIFT"
    find(".expand-btn").click
    assert_selector ".check-output code", text: "Plan: 2 to add, 1 to change, 0 to destroy."
  end
end

require "test_helper"


class ProjectsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :drift)
    @drift_check = @environment.drift_checks.create!(
      status: :drift,
      add_count: 2,
      change_count: 1,
      destroy_count: 0,
      raw_output: "Plan: 2 to add, 1 to change, 0 to destroy."
    )
    @environment.reload
    @project.reload
  end

  test "shows project details" do
    get project_path(@project.key)
    assert_response :success
    assert_select "h1", "Test Project"
  end

  test "shows drift check history" do
    get project_environment_path(@project.key, @environment.key)
    assert_response :success
    assert_select ".check-row", 1
  end

  test "returns 404 for unknown project" do
    get project_path("unknown-project")
    assert_response :not_found
  end

  test "shows raw output in expandable section" do
    get project_environment_path(@project.key, @environment.key)
    assert_response :success
    assert_select ".check-output code", /Plan: 2 to add/
  end
end

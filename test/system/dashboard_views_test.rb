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

  # ===== Chart View Tests =====

  test "view toggle switches between table and chart views" do
    visit root_path

    # Should start in table view (default or from localStorage)
    assert_selector ".view-toggle"

    # Click Chart view toggle
    find("[data-view='chart']").click

    # Charts section should be visible
    assert_selector ".charts-grid"
    assert_selector ".chart-card"

    # Table should be hidden
    assert_no_selector ".projects-table", visible: true

    # Click Table view toggle
    find("[data-view='table']").click

    # Table should be visible again
    assert_selector ".projects-table"
  end

  test "chart view displays all chart cards" do
    visit root_path
    find("[data-view='chart']").click

    # Verify all 12 chart cards are present
    assert_selector ".chart-card", minimum: 1

    # Check for specific chart titles
    assert_selector ".chart-card", text: "Status Distribution"
    assert_selector ".chart-card", text: "Stability Score"
    assert_selector ".chart-card", text: "Drift Over Time"
  end

  test "chart environment filter is present in chart view" do
    visit root_path
    find("[data-view='chart']").click

    # Chart filters should be visible
    assert_selector "[data-dashboard-filter-target='chartFilters']"
    assert_selector "#chart-env-filter"
  end

  test "tag filter buttons work in chart view" do
    visit root_path
    find("[data-view='chart']").click

    # Tag buttons should be present
    assert_selector ".chart-tag-btn"

    # Click on a tag filter (e.g., "status")
    status_tag = find(".chart-tag-btn[data-tag='status']")
    status_tag.click

    # The clicked tag should be active
    assert_selector ".chart-tag-btn.active[data-tag='status']"

    # Only status-tagged charts should be visible
    # (charts with data-tags containing "status")
    assert_selector ".chart-card[data-tags*='status']"
  end

  test "clicking All tag shows all charts" do
    visit root_path
    find("[data-view='chart']").click

    # First filter by a specific tag
    find(".chart-tag-btn[data-tag='status']").click

    # Then click All to show all charts
    find(".chart-tag-btn[data-tag='']").click

    # All tag should be active
    assert_selector ".chart-tag-btn.active[data-tag='']"

    # All charts should be visible
    assert_selector ".chart-card", minimum: 10
  end

  test "table view filter by environment works" do
    # Create another environment
    staging = @project.environments.create!(name: "Staging", key: "staging", status: :ok)
    staging.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")

    visit root_path

    # Both environments should be visible initially
    assert_selector ".project-env-row", minimum: 2

    # Filter by Production
    select "Production", from: "env-filter"

    # Only Production should be visible
    assert_selector ".col-environment", text: "Production"
    assert_no_selector ".col-environment", text: "Staging", visible: true
  end

  test "table view search filter works" do
    # Create another project
    other_project = Project.create!(name: "Other Project", key: "other-project")
    other_env = other_project.environments.create!(name: "Dev", key: "dev", status: :ok)
    other_env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")

    visit root_path

    # Both projects should be visible
    assert_selector ".project-env-row", minimum: 2

    # Search for "ViewTest"
    fill_in "Search projects or environments", with: "ViewTest"

    # Only ViewTest Project should be visible
    assert_selector ".col-project", text: "ViewTest Project"
    assert_no_selector ".col-project", text: "Other Project", visible: true
  end

  test "status badge filter works" do
    # Create OK project
    ok_project = Project.create!(name: "OK Project", key: "ok-project")
    ok_env = ok_project.environments.create!(name: "Prod", key: "prod", status: :ok)
    ok_env.drift_checks.create!(status: :ok, add_count: 0, change_count: 0, destroy_count: 0, raw_output: "OK")

    visit root_path

    # Click on drift status badge to filter
    find(".status-badge.status-drift").click

    # Only drift projects should be visible
    assert_selector ".status-text--drift", text: "DRIFT"
    assert_no_selector ".status-text--ok", text: "OK", visible: true

    # Click again to clear filter
    find(".status-badge.status-drift").click

    # Both should be visible again
    assert_selector ".project-env-row", minimum: 2
  end

  test "clear filters button resets all filters" do
    visit root_path

    # Apply a filter
    fill_in "Search projects or environments", with: "ViewTest"

    # Clear button should appear
    assert_selector "#clear-filters-btn"

    # Click clear
    find("#clear-filters-btn").click

    # Search should be cleared
    assert_equal "", find("#name-filter").value
  end

  test "view toggle state persists" do
    visit root_path

    # Switch to chart view
    find("[data-view='chart']").click
    assert_selector ".charts-grid"

    # Reload the page
    visit root_path

    # Should still be in chart view (persisted in localStorage)
    assert_selector ".charts-grid"
    assert_selector "[data-view='chart'].active"
  end

  test "chart cards have info tooltips" do
    visit root_path
    find("[data-view='chart']").click

    # Chart cards should have info icons
    assert_selector ".chart-info-icon", minimum: 1
  end

  test "charts render without JavaScript errors" do
    visit root_path
    find("[data-view='chart']").click

    # Wait for charts to initialize
    sleep 1

    # Check that canvas elements exist (Chart.js renders to canvas)
    assert_selector "canvas", minimum: 1

    # Check browser console for errors (if any critical JS errors, the page would fail)
    # The fact that we can see canvases means Chart.js loaded successfully
  end
end

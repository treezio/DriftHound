require "test_helper"

class NotificationJobTest < ActiveJob::TestCase
  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
  end

  test "calls NotificationService with correct parameters" do
    NotificationService.expects(:new).with(@environment, "ok", "drift").returns(mock(call: nil))

    NotificationJob.perform_now(
      environment_id: @environment.id,
      old_status: "ok",
      new_status: "drift"
    )
  end

  test "handles missing environment gracefully" do
    Rails.logger.expects(:warn).with(regexp_matches(/Environment not found: 99999/))

    assert_nothing_raised do
      NotificationJob.perform_now(
        environment_id: 99999,
        old_status: "ok",
        new_status: "drift"
      )
    end
  end

  test "runs on default queue" do
    assert_equal "default", NotificationJob.new.queue_name
  end
end

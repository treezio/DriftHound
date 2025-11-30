require "test_helper"

class EnvironmentNotificationTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @project = Project.create!(name: "Test Project", key: "test-project")
    @environment = @project.environments.create!(name: "Production", key: "production", status: :ok)
  end

  test "enqueues notification job when status changes" do
    assert_enqueued_with(job: NotificationJob) do
      @environment.update!(status: :drift)
    end
  end

  test "enqueues notification job when status changes from drift to ok" do
    @environment.update!(status: :drift)

    assert_enqueued_with(job: NotificationJob) do
      @environment.update!(status: :ok)
    end
  end

  test "enqueues notification job when status changes from ok to error" do
    assert_enqueued_with(job: NotificationJob) do
      @environment.update!(status: :error)
    end
  end

  test "does not enqueue job when status does not change" do
    @environment.update!(status: :drift)

    assert_no_enqueued_jobs(only: NotificationJob) do
      @environment.update!(name: "Production Updated")
    end
  end

  test "does not enqueue job when other attributes change" do
    assert_no_enqueued_jobs(only: NotificationJob) do
      @environment.update!(last_checked_at: Time.current)
    end
  end
end

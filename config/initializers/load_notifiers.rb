# Load Notifiers module and its classes
# This ensures the module is available for tests and background jobs
require Rails.root.join("app/notifiers")
require Rails.root.join("app/notifiers/base")
require Rails.root.join("app/notifiers/slack")

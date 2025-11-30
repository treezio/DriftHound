# Define Notifiers module and load its classes
# This ensures the module is available for tests and background jobs
module Notifiers
end

require Rails.root.join("app/notifiers/base")
require Rails.root.join("app/notifiers/slack")

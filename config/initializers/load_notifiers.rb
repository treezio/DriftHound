# Explicitly load notification adapters
# This is needed because Zeitwerk doesn't auto-discover the Notifiers namespace

require Rails.root.join("app/notifiers")
require Rails.root.join("app/notifiers/base")
require Rails.root.join("app/notifiers/slack")

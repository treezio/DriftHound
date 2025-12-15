# frozen_string_literal: true

# Drift check retention configuration
# Controls how long drift checks are kept in the database
#
# DRIFT_CHECK_RETENTION_DAYS: Number of days to retain drift checks (default: 90)
#   - Checks older than this will be automatically deleted when new checks are created
#   - Set to 0 to disable retention (keep all checks indefinitely)
#
# Examples:
#   DRIFT_CHECK_RETENTION_DAYS=30  # Keep 30 days of history
#   DRIFT_CHECK_RETENTION_DAYS=90  # Keep 90 days of history (default)
#   DRIFT_CHECK_RETENTION_DAYS=0   # Disable retention, keep all checks

Rails.application.config.drift_check_retention_days = ENV.fetch("DRIFT_CHECK_RETENTION_DAYS", 90).to_i

module ApplicationHelper
  def github_oauth_enabled?
    Rails.application.config.oauth[:github][:enabled]
  end
end

# OAuth Configuration
#
# Configure OAuth providers via environment variables.
# Currently supports GitHub, with architecture for future providers.
#
# Team mappings support multiple teams per role using comma-separated values:
#   GITHUB_TEAM_ADMIN=platform-admins,security-team
#   GITHUB_TEAM_EDITOR=developers,contractors
#   GITHUB_TEAM_VIEWER=read-only,auditors

def parse_team_list(env_value)
  return [] if env_value.blank?
  env_value.split(",").map(&:strip).reject(&:blank?)
end

Rails.application.config.oauth = {
  github: {
    enabled: ENV.fetch("GITHUB_OAUTH_ENABLED", "false") == "true",
    client_id: ENV["GITHUB_CLIENT_ID"],
    client_secret: ENV["GITHUB_CLIENT_SECRET"],
    organization: ENV["GITHUB_ORG"],
    team_mappings: {
      admin: parse_team_list(ENV["GITHUB_TEAM_ADMIN"]),
      editor: parse_team_list(ENV["GITHUB_TEAM_EDITOR"]),
      viewer: parse_team_list(ENV["GITHUB_TEAM_VIEWER"])
    }.select { |_, teams| teams.any? }
  }
}

# Validate GitHub OAuth configuration when enabled
if Rails.application.config.oauth[:github][:enabled]
  github_config = Rails.application.config.oauth[:github]

  missing = []
  missing << "GITHUB_CLIENT_ID" if github_config[:client_id].blank?
  missing << "GITHUB_CLIENT_SECRET" if github_config[:client_secret].blank?
  missing << "GITHUB_ORG" if github_config[:organization].blank?

  if missing.any?
    raise "GitHub OAuth is enabled but missing required environment variables: #{missing.join(', ')}"
  end

  if github_config[:team_mappings].empty?
    raise "GitHub OAuth is enabled but no team mappings configured. Set at least one of: GITHUB_TEAM_ADMIN, GITHUB_TEAM_EDITOR, GITHUB_TEAM_VIEWER"
  end
end

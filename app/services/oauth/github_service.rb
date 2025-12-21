require "net/http"
require "json"

module Oauth
  class GithubService < BaseService
    GITHUB_TOKEN_URL = "https://github.com/login/oauth/access_token"
    GITHUB_API_URL = "https://api.github.com"

    def self.provider_name
      "github"
    end

    def self.authorization_url(state:, redirect_uri:)
      config = Rails.application.config.oauth[:github]
      params = {
        client_id: config[:client_id],
        redirect_uri: redirect_uri,
        scope: "read:org user:email",
        state: state
      }
      "https://github.com/login/oauth/authorize?#{params.to_query}"
    end

    protected

    def exchange_code_for_token
      config = Rails.application.config.oauth[:github]

      uri = URI(GITHUB_TOKEN_URL)
      response = Net::HTTP.post_form(uri, {
        client_id: config[:client_id],
        client_secret: config[:client_secret],
        code: @code
      })

      # GitHub returns URL-encoded response by default
      params = URI.decode_www_form(response.body).to_h

      if params["error"]
        raise TokenExchangeError, params["error_description"] || params["error"]
      end

      params["access_token"]
    end

    def fetch_user_info(token)
      user_data = github_api_get("/user", token)
      email = user_data["email"] || fetch_primary_email(token)

      {
        uid: user_data["id"].to_s,
        email: email,
        username: user_data["login"],
        name: user_data["name"]
      }
    end

    def determine_role(token, _user_info)
      config = Rails.application.config.oauth[:github]
      organization = config[:organization]
      team_mappings = config[:team_mappings]

      user_teams = fetch_user_teams(token, organization)
      matched_roles = []

      team_mappings.each do |role, team_slugs|
        next if team_slugs.blank?
        # team_slugs is an array of teams that grant this role
        team_slugs_downcased = team_slugs.map(&:downcase)
        matched_roles << role if (user_teams & team_slugs_downcased).any?
      end

      if matched_roles.empty?
        raise OrganizationAccessError, "User is not a member of any configured team in #{organization}"
      end

      highest_role(matched_roles)
    end

    private

    def fetch_primary_email(token)
      emails = github_api_get("/user/emails", token)
      primary = emails.find { |e| e["primary"] && e["verified"] }
      primary&.dig("email") || emails.first&.dig("email")
    end

    def fetch_user_teams(token, organization)
      teams = github_api_get("/user/teams", token)
      teams
        .select { |team| team.dig("organization", "login")&.downcase == organization.downcase }
        .map { |team| team["slug"].downcase }
    end

    def github_api_get(path, token)
      uri = URI("#{GITHUB_API_URL}#{path}")
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{token}"
      request["Accept"] = "application/vnd.github+json"
      request["X-GitHub-Api-Version"] = "2022-11-28"

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise UserInfoError, "GitHub API error: #{response.code} - #{response.body}"
      end

      JSON.parse(response.body)
    end
  end
end

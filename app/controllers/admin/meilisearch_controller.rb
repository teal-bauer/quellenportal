class Admin::MeilisearchController < ApplicationController
  http_basic_authenticate_with(
    name: Rails.application.credentials.dig(:admin, :username) || "admin",
    password: Rails.application.credentials.dig(:admin, :password) || raise("admin.password credential not set")
  )

  def index
    repo = MeilisearchRepository.new

    @global_stats = repo.get("/stats")
    @tasks = repo.get("/tasks?limit=20")["results"]
    @ip_auto_banned = IpBlocker::AUTO_BANNED.to_a.sort
    @rack_attack_enabled = Rack::Attack.enabled
  rescue => e
    @error = e.message
  end
end

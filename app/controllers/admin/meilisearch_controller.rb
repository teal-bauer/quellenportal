class Admin::MeilisearchController < ApplicationController
  http_basic_authenticate_with(
    name: Rails.application.credentials.dig(:admin, :username) || "admin",
    password: Rails.application.credentials.dig(:admin, :password) || raise("admin.password credential not set")
  )

  def index
    repo = MeilisearchRepository.new
    @global_stats = repo.get("/stats")
    @tasks        = repo.get("/tasks?limit=20")["results"]
    @auto_banned  = IpBlocker::AUTO_BANNED_MUTEX.synchronize { IpBlocker::AUTO_BANNED.sort_by { |_, e| e[:banned_at] }.reverse }
    @config_bans  = IpBlocker::CONFIG_BANNED.keys.sort
    @runtime_bans = IpBlocker::RUNTIME_BANNED_MUTEX.synchronize { IpBlocker::RUNTIME_BANNED.keys.sort }
    @rack_attack_enabled = Rack::Attack.enabled
  rescue => e
    @error = e.message
  end

  def add_manual_ban
    ip = params[:ip].to_s.strip
    IpBlocker.add_manual_ban!(ip)
    redirect_to admin_status_path, notice: "Banned #{ip}"
  rescue => e
    redirect_to admin_status_path, alert: "Invalid: #{e.message}"
  end

  def remove_manual_ban
    IpBlocker.remove_manual_ban!(params[:ip].to_s.strip)
    redirect_to admin_status_path
  end

  def remove_auto_ban
    IpBlocker.remove_auto_ban!(params[:ip].to_s.strip)
    redirect_to admin_status_path
  end
end

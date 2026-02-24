class Admin::MeilisearchController < ApplicationController
  http_basic_authenticate_with(
    name: Rails.application.credentials.dig(:admin, :username) || "admin",
    password: Rails.application.credentials.dig(:admin, :password) || raise("admin.password credential not set")
  )

  def index
    recent_cutoff = (Time.now.utc - 24.hours).strftime("%Y-%m-%dT%H:%M:%SZ")
    threads = {
      stats:      Thread.new { MeilisearchRepository.new.get("/stats") },
      enqueued:   Thread.new { MeilisearchRepository.new.get("/tasks?statuses=enqueued&limit=20") },
      processing: Thread.new { MeilisearchRepository.new.get("/tasks?statuses=processing&limit=20") },
      finished:   Thread.new { MeilisearchRepository.new.get("/tasks?statuses=succeeded,failed&limit=20&afterFinishedAt=#{recent_cutoff}") }
    }
    @global_stats      = threads[:stats].value
    enqueued_resp      = threads[:enqueued].value
    processing_resp    = threads[:processing].value
    finished_resp      = threads[:finished].value
    @tasks_enqueued    = enqueued_resp["results"]
    @tasks_processing  = processing_resp["results"]
    @tasks_finished    = finished_resp["results"]
    @total_enqueued    = enqueued_resp["total"]
    @total_processing  = processing_resp["total"]
    @total_finished    = finished_resp["total"]
    @auto_banned  = IpBlocker::AUTO_BANNED_MUTEX.synchronize { IpBlocker::AUTO_BANNED.sort_by { |_, e| e[:banned_at] }.reverse }
    @manual_bans  = build_merged_bans
  rescue => e
    @error = e.message
  end

  def add_manual_ban
    ip      = params[:ip].to_s.strip
    comment = params[:comment].to_s.strip
    IpBlocker.add_manual_ban!(ip, comment: comment)
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

  private

  def build_merged_bans
    bans = []
    IpBlocker::CONFIG_BANNED.each { |raw, _| bans << { ip: raw, source: "config", comment: "" } }
    IpBlocker::RUNTIME_BANNED_MUTEX.synchronize do
      IpBlocker::RUNTIME_BANNED.each { |raw, e| bans << { ip: raw, source: "runtime", comment: e[:comment] } }
    end
    bans.sort_by { |b| b[:ip] }
  end
end

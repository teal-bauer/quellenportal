module ApplicationHelper
  # Format ISO 8601 duration (e.g. "PT0.000236339S", "PT1802.742S", "PT2M3.5S") to human-readable
  def format_iso8601_duration(str)
    return "-" if str.blank?

    # Parse hours, minutes, seconds from PT[nH][nM][nS]
    hours   = str[/(\d+)H/, 1].to_f
    minutes = str[/(\d+)M/, 1].to_f
    seconds = str[/([0-9.]+)S/, 1].to_f

    total_seconds = hours * 3600 + minutes * 60 + seconds

    if total_seconds < 0.001
      "#{(total_seconds * 1_000_000).round}µs"
    elsif total_seconds < 1
      "#{(total_seconds * 1000).round}ms"
    elsif total_seconds < 60
      "#{total_seconds.round(2)}s"
    elsif total_seconds < 3600
      m = (total_seconds / 60).floor
      s = (total_seconds % 60).round
      "#{m}m #{s}s"
    else
      h = (total_seconds / 3600).floor
      m = ((total_seconds % 3600) / 60).round
      "#{h}h #{m}m"
    end
  end
end

#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sinatra'
require 'sqlite3'
require 'json'
require 'time'

DATABASE_PATH = File.join(__dir__, '..', 'db', 'pings.db')

# Ping interval in seconds (probes run every 30s)
PING_INTERVAL = 30
# Gap threshold to consider power outage (2 minutes without data)
POWER_OUTAGE_GAP = 120

configure do
  set :bind, '0.0.0.0'
  set :port, 4001
  set :environment, :production
  set :permitted_hosts, []
end

helpers do
  def db
    @db ||= SQLite3::Database.new(DATABASE_PATH, readonly: true).tap do |d|
      d.results_as_hash = true
    end
  end

  def fetch_pings
    db.execute(<<-SQL)
      SELECT
        id, datetime, success, dns_ip, dns_latency, router_state,
        weather_temperature_celsius, weather_humidity_percentage,
        weather_precipitation_mm, weather_wind_speed_kmh, weather_cloud_cover_percentage
      FROM pings
      ORDER BY datetime DESC
    SQL
  end

  def detect_firmware_update?(router_state)
    return false if router_state.nil? || router_state.empty?
    state = JSON.parse(router_state) rescue nil
    return false unless state
    # Starlink reports software update in dishGetStatus
    state.to_s.downcase.include?('software_update') ||
      state.to_s.downcase.include?('updating') ||
      state.to_s.downcase.include?('reboot')
  end

  def ping_color(ping, prev_ping)
    # Check for power outage (gap in data)
    if prev_ping && power_outage?(ping, prev_ping)
      return '#000000'
    end

    # Check connectivity
    if ping['success'] == 0
      # Check if firmware update
      if detect_firmware_update?(ping['router_state'])
        return '#ababab'
      end
      return '#e70202'
    end

    # Latency-based colors
    latency = ping['dns_latency'].to_i
    case latency
    when 0..40 then '#196127'
    when 41..80 then '#239a3b'
    else '#f8c300'
    end
  end

  def parse_utc(datetime_str)
    Time.parse(datetime_str + ' UTC')
  end

  def power_outage?(ping, prev_ping)
    return false unless prev_ping
    current = parse_utc(ping['datetime'])
    previous = parse_utc(prev_ping['datetime'])
    (previous - current).abs > POWER_OUTAGE_GAP
  end

  def find_last_power_outage(pings)
    pings.each_cons(2) do |current, prev|
      if power_outage?(current, prev)
        return parse_utc(current['datetime'])
      end
    end
    nil
  end

  def find_last_connectivity_loss(pings)
    ping = pings.find { |p| p['success'] == 0 && !detect_firmware_update?(p['router_state']) }
    ping ? parse_utc(ping['datetime']) : nil
  end

  def find_last_firmware_update(pings)
    ping = pings.find { |p| p['success'] == 0 && detect_firmware_update?(p['router_state']) }
    ping ? parse_utc(ping['datetime']) : nil
  end

  def time_ago(time)
    return 'Never' unless time
    seconds = Time.now.utc - time
    return 'just now' if seconds < 60

    minutes = (seconds / 60).to_i
    return "#{minutes}m ago" if minutes < 60

    hours = (minutes / 60).to_i
    return "#{hours}h ago" if hours < 24

    days = (hours / 24).to_i
    "#{days}d ago"
  end

  def format_tooltip(ping)
    parts = []

    if ping['success'] == 1
      parts << "#{ping['dns_latency']}ms"
    else
      parts << 'No connection'
    end

    if ping['weather_temperature_celsius']
      parts << "#{ping['weather_temperature_celsius'].round}°C"
    end

    if ping['weather_cloud_cover_percentage']
      parts << "#{ping['weather_cloud_cover_percentage']}% clouds"
    end

    if ping['weather_wind_speed_kmh']
      parts << "#{ping['weather_wind_speed_kmh'].round} km/h wind"
    end

    datetime = parse_utc(ping['datetime']).strftime('%Y-%m-%d %H:%M:%S UTC')
    dns_info = ping['dns_ip'] ? " • DNS: #{ping['dns_ip']}" : ''

    "#{datetime}#{dns_info}\n#{parts.join(' • ')}"
  end

  def current_weather(pings)
    latest = pings.first
    return nil unless latest && latest['weather_temperature_celsius']

    temp = latest['weather_temperature_celsius'].round
    clouds = latest['weather_cloud_cover_percentage'] || 0

    condition = case clouds
    when 0..10 then 'clear'
    when 11..30 then 'mostly clear'
    when 31..60 then 'partly cloudy'
    when 61..80 then 'mostly cloudy'
    else 'overcast'
    end

    "#{temp}°C, #{condition}"
  end

  def group_pings_by_day(pings)
    pings.group_by do |ping|
      parse_utc(ping['datetime']).strftime('%Y-%m-%d')
    end.sort_by { |date, _| date }.reverse.to_h
  end

  def group_pings_by_day_and_hour(pings)
    # First group by day
    by_day = pings.group_by do |ping|
      parse_utc(ping['datetime']).strftime('%Y-%m-%d')
    end.sort_by { |date, _| date }.reverse.to_h

    # Then group each day's pings by hour, with earlier pings first within each hour
    by_day.transform_values do |day_pings|
      day_pings.group_by do |ping|
        parse_utc(ping['datetime']).hour
      end.sort_by { |hour, _| hour }.reverse.to_h.transform_values(&:reverse)
    end
  end

  def format_day_label(date_str)
    date = Date.parse(date_str)
    today = Date.today

    if date == today
      'Today'
    elsif date == today - 1
      'Yesterday'
    else
      date.strftime('%b %d')
    end
  end

  def format_hour_label(hour)
    format('%02d:00', hour)
  end
end

get '/' do
  @pings = fetch_pings
  @pings_json = @pings.to_json
  @last_power_outage = find_last_power_outage(@pings)
  @last_connectivity_loss = find_last_connectivity_loss(@pings)
  @last_firmware_update = find_last_firmware_update(@pings)
  @current_weather = current_weather(@pings)

  erb :index
end


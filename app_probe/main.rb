require 'time'
require 'pry'
require 'sqlite3'
require 'dotenv/load'
require 'net/http'
require 'json'

DATABASE_PATH = File.join(__dir__, '..', 'db', 'pings.db')

LATITUDE = ENV.fetch('LATITUDE', '-24.00').to_f
LONGITUDE = ENV.fetch('LONGITUDE', '-47.00').to_f
TIMEZONE = ENV.fetch('TIMEZONE', 'America/Sao_Paulo')

class PingTracker
  def initialize
    @db = SQLite3::Database.new(DATABASE_PATH)
  end

  def run_forever
    loop do
      result = Internet.new.check
      weather = Weather.new.fetch
      record_ping(result, weather)
      print_progress_bar(result[:success])
      sleep 30
    end
  end

  private

  def record_ping(ping, weather)
    @db.execute(
      <<-SQL,
        INSERT INTO pings
          (datetime, success, dns_ip, dns_latency, router_state,
           weather_temperature_celsius, weather_humidity_percentage,
           weather_precipitation_mm, weather_wind_speed_kmh, weather_cloud_cover_percentage)
          VALUES (?, ?, ?, ?, JSONB(?), ?, ?, ?, ?, ?)
      SQL
      [
        Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'),
        ping.fetch(:success) ? 1 : 0,
        ping.fetch(:dns_ip),
        ping.fetch(:dns_latency),
        ping.fetch(:router_state),
        weather.fetch(:temperature_celsius),
        weather.fetch(:humidity_percentage),
        weather.fetch(:precipitation_mm),
        weather.fetch(:wind_speed_kmh),
        weather.fetch(:cloud_cover_percentage)
      ]
    )
  end

  def print_progress_bar(success)
    @print_columns ||= 0
    @print_columns += 1
    print success ? '✓' : '✗'

    if @print_columns == 120
      puts ''
      @print_columns = 0
    end
  end
end

class Internet
  PUBLIC_DNS = {
    '1.1.1.1' => 'Cloudflare Primary',
    '1.0.0.1' => 'Cloudflare Secondary',
    '8.8.8.8' => 'Google Primary',
    '8.8.4.4' => 'Google Secondary',
    '200.160.2.3' => 'NIC.br Primary',
    '200.160.0.5' => 'NIC.br Secondary',
  }
  TIMEOUT = 3
  ATTEMPTS = 1

  def check
    timestamp = Time.now.utc
    result = nil

    PUBLIC_DNS.keys.each do |dns_ip|
      result = ping(dns_ip)
      break if result.fetch(:success)
    end

    success = result.fetch(:success)
    {
      timestamp:,
      success:,
      dns_ip: success ? result.fetch(:ip) : nil,
      dns_latency: success ? result.fetch(:latency) : nil,
      router_state: success ? nil : fetch_router_state,
    }
  end

  def fetch_router_state
    `grpcurl -plaintext -d '{"get_status":{}}' 192.168.100.1:9200 SpaceX.API.Device.Device/Handle 2>&1`
  end

  private

  def ping(ip)
    output = `ping -c #{ATTEMPTS} -W #{TIMEOUT} #{ip} 2>&1`
    success = !output.include?('100% packet loss')
    latency = output[/round-trip min\/avg\/max\/stddev = (\d+(?:\.\d+)?)/, 1]&.to_f&.round if success

    { ip:, success:, latency: }
  end
end

class Weather
  API_URL = 'https://api.open-meteo.com/v1/forecast?' \
            "latitude=#{LATITUDE}&longitude=#{LONGITUDE}" \
            '&current=temperature_2m,relative_humidity_2m,precipitation,wind_speed_10m,cloud_cover' \
            "&timezone=#{TIMEZONE}&forecast_days=1"

  def fetch
    data =
      begin
        response = Net::HTTP.get(URI(API_URL))
        JSON.parse(response)
      rescue => e
        warn "Weather fetch failed: #{e.message}"
        {}
      end

    {
      temperature_celsius: data.dig('current', 'temperature_2m'),
      humidity_percentage: data.dig('current', 'relative_humidity_2m'),
      precipitation_mm: data.dig('current', 'precipitation'),
      wind_speed_kmh: data.dig('current', 'wind_speed_10m'),
      cloud_cover_percentage: data.dig('current', 'cloud_cover')
    }
  end
end

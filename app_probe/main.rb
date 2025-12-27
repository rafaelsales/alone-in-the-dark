require 'time'
require 'pry'
require 'sqlite3'
require 'dotenv/load'

DATABASE_PATH = File.join(__dir__, '..', 'db', 'pings.db')

class PingTracker
  def initialize
    @db = SQLite3::Database.new(DATABASE_PATH)
  end

  def run_forever
    loop do
      result = Internet.new.check
      record_ping(result)
      print_progress_bar(result[:success])
      sleep 30
    end
  end

  private

  def record_ping(result)
    @db.execute(
      <<-SQL,
        INSERT INTO pings
          (datetime, success, dns_ip, dns_latency, router_state)
          VALUES (?, ?, ?, ?, JSONB(?))
      SQL
      [
        Time.now.utc.strftime('%Y-%m-%d %H:%M:%S'),
        result.fetch(:success) ? 1 : 0,
        result.fetch(:dns_ip),
        result.fetch(:dns_latency),
        result.fetch(:router_state)
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


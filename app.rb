require 'time'
require 'twitter'
require 'dotenv/load'

class DowntimeTracker
  def run_forever
    loop do
      down = Internet.new.down?

      if down_since.nil?
        if down
          self.down_since = Time.now
          puts 'Internet is down!'
        else
          print_progress_bar
        end
      elsif !down
        TwitterClient.new(downtime_minutes).post
        self.down_since = nil
        puts 'Internet is back up!'
      end

      sleep 30
    end
  end

  private

  attr_accessor :down_since

  def print_progress_bar
    @print_columns ||= 0
    @print_columns += 1
    print '.'

    if @print_columns == 120
      puts ''
      @print_columns = 0
    end
  end

  def downtime_minutes
    ((Time.now - down_since) / 60).ceil
  end
end

class Internet
  PUBLIC_DNS = {
    '1.1.1.1' => 'Cloudflare',
    '8.8.8.8' => 'Google Primary',
    '8.8.4.4' => 'Google Secondary',
  }
  TIMEOUT = 3
  ATTEMPTS = 1

  def down?
    down = false

    PUBLIC_DNS.each do |ip, name|
      ip_down = ip_down?(ip)
      down ||= ip_down
      puts "#{name} (#{ip}) is unreachable" if ip_down
    end

    down
  end

  private

  def ip_down?(ip)
    output = `ping -c #{ATTEMPTS} -W #{TIMEOUT} #{ip} 2>&1`
    output.include?('100% packet loss')
  end
end

class TwitterClient
  CLIENT = Twitter::REST::Client.new do |config|
    config.consumer_key        = ENV.fetch('TWITTER_CONSUMER_KEY')
    config.consumer_secret     = ENV.fetch('TWITTER_CONSUMER_SECRET')
    config.access_token        = ENV.fetch('TWITTER_ACCESS_TOKEN')
    config.access_token_secret = ENV.fetch('TWITTER_TOKEN_SECRET')
  end
  MESSAGE_TEMPLATE = ENV.fetch('MESSAGE_TEMPLATE')
  MESSAGE_THREAD_ID = ENV['MESSAGE_THREAD_ID'].yield_self { |s| s if s != '' }
  ISP_BILL_AMOUNT = ENV.fetch('ISP_BILL_AMOUNT').to_f

  def initialize(downtime_minutes)
    self.downtime_minutes = downtime_minutes
  end

  def post
    message = MESSAGE_TEMPLATE % [formatted_downtime, expected_isp_bill_discount]

    puts message
    tweet = CLIENT.update(message, in_reply_to_status_id: MESSAGE_THREAD_ID)
    puts "Posted at #{tweet.url}"
  end

  private

  attr_accessor :downtime_minutes

  def expected_isp_bill_discount
    minute_cost = ISP_BILL_AMOUNT / 30 / 24 / 60
    discount = (minute_cost * downtime_minutes).ceil(2)
    ("%.2f" % discount).gsub('.', ',')
  end

  def formatted_downtime
    string = ""
    string << "#{downtime_minutes / 60}h " if downtime_minutes > 60
    string << "#{downtime_minutes % 60}m"
    string
  end
end

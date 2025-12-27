#!/usr/bin/env ruby
# frozen_string_literal: true

require 'sqlite3'

DATABASE_PATH = File.join(__dir__, 'pings.db')

db = SQLite3::Database.new(DATABASE_PATH)

db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS pings (
    id INTEGER PRIMARY KEY,
    datetime DATETIME NOT NULL,
    success INTEGER NOT NULL,
    dns_ip TEXT,
    dns_latency INTEGER,
    router_state BLOB,  -- Use jsonb() when inserting for binary JSON storage
    weather_temperature_celsius REAL,
    weather_humidity_percentage INTEGER,
    weather_precipitation_mm REAL,
    weather_wind_speed_kmh REAL,
    weather_cloud_cover_percentage INTEGER
  );
SQL

db.execute <<-SQL
  CREATE INDEX IF NOT EXISTS idx_pings_datetime ON pings(datetime);
SQL

db.execute <<-SQL
  CREATE INDEX IF NOT EXISTS idx_pings_success ON pings(success);
SQL

puts "Database setup complete: #{DATABASE_PATH}"
puts "Table 'pings' created successfully."


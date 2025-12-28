# Frontend

The frontend app renders the ping data collected by the probe app.

## Running

```bash
cd app_frontend
bundle install
bundle exec ruby main.rb
```

The app runs at http://localhost:4567

## Features

The pings are rendered as small squares (10px x 10px) in GitHub profile contributions style.
Most recent pings appear first (top-left).

### Ping square colors:
- 0-40ms: #196127
- 41-80ms: #239a3b
- 80ms+: #f8c300
- Starlink firmware update: #ababab
- No connectivity: #e70202
- Power outage: #000000

### Header displays:
- Last power outage: X days, hours or minutes ago
- Last connectivity loss: X days, hours or minutes ago
- Last Starlink firmware update: X days, hours or minutes ago
- Current weather: temperature and conditions (e.g. "31°C, partly cloudy")

### Tooltip on hover:
- When hovering over a ping square, show detailed ping information (datetime, dns latency, dns ip)
- When hovering over a ping square, show weather conditions at that moment alongside latency
- Format: "42ms • 31°C • 66% clouds • 16 km/h wind"

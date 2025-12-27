# Frontend

The frontend app renders the ping data collected by the probe app.

The pings are rendered as small squares (10px x 10px) in GitHub profile contributions style.

Ping square colors:
- 0-40ms: #239a3b
- 41-80ms: #a1d736
- 80ms+: #fff308
- Starlink firmware update: #ababab
- No connectivity: #e70202
- Power outage: #000000

The header of the page should be thin and should display:
- Last power outage: X days, hours or minutes ago
- Last connectivity loss: X days, hours or minutes ago
- Last Starlink firmware update: X days, hours or minutes ago
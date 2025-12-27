# Probe

A daemon service that notifies on Twitter when your ISP is down.

### How we verify that the ISP is working?

We ping a few reliable public DNS (Cloudflare and Google Primary and Secondary)
every 30s - if all those public DNS services are unreachable, that means
your connection is down.

## Recommended Setup

I use this app on Raspberry Pi 3 - even though it has Wi-Fi, I prefer to
use the ethernet port into my main ISP router to make sure that the app
isn't affected by a spotty WiFi connection.

## How to setup

1. Install Ruby - `sudo apt-get install ruby ruby-dev`
1. Clone the repo on the computer that will running the daemon
1. Install dependencies: `gem install bundler && bundle install`
1. Copy `.env.sample` to `.env` and customize the environment variables
1. Run `./probe` to start/test the app
   If the app works ok, press `CTRL+C` to stop.
   It's recommended to simulate a broken connection to make sure everything works.
1. Run `./install-systemd-service.sh` to install the daemon on SystemD

Done - the app should now be running and will always start on reboot.

### Logging

You can use `journalctl -u probe.service` to open the log.

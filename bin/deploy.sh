#!/bin/bash
ssh pi3 'cd /opt/net-pulse && git add db/pings.db && git commit -m "Update DB" && git pull && bin/service_restart'

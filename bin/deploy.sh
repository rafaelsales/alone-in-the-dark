#!/bin/bash
ssh pi3 'cd /opt/net-pulse && git pull && bin/service_restart'

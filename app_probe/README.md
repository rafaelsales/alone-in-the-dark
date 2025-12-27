# Probe

The probe is responsible for testing connectivity via periodic pings against predefined DNS providers (Cloudflare, Google and NIC.br).

The probe stores the timestamp of each ping, along with the first DNS server that succeeded and the ping latency. When the ping against all DNS servers fail, we store the status of the Starlink router to help troubleshooting the issue.

Along with ping data, the probe also stores the some current weather information.
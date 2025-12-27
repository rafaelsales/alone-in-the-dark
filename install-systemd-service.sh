sudo cp /home/pi/starlink-monitor/probe.service /etc/systemd/system/
sudo systemctl enable probe.service
sudo systemctl start probe.service

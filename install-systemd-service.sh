#!/bin/bash

# Don't run this script with sudo
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Do not run this script with sudo."
    echo "Run as your regular user: ./install-systemd-service.sh"
    echo "The script will prompt for sudo when needed."
    exit 1
fi

# Get the current directory (absolute path)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Get the user running the script
SERVICE_USER="$USER"

echo "Installing NetPulse services..."
echo "Installation directory: $SCRIPT_DIR"
echo "Service will run as user: $SERVICE_USER"

# Create temporary service files with updated paths and user
echo "Generating service files..."
TEMP_DIR=$(mktemp -d)

# Generate probe.service
sed -e "s|User=.*|User=$SERVICE_USER|g" \
    -e "s|Group=.*|Group=$SERVICE_USER|g" \
    -e "s|WorkingDirectory=.*|WorkingDirectory=$SCRIPT_DIR/app_probe|g" \
    -e "s|ExecStart=.*|ExecStart=$SCRIPT_DIR/app_probe/bin/probe|g" \
    "$SCRIPT_DIR/probe.service" > "$TEMP_DIR/probe.service"

# Generate frontend.service
sed -e "s|User=.*|User=$SERVICE_USER|g" \
    -e "s|Group=.*|Group=$SERVICE_USER|g" \
    -e "s|WorkingDirectory=.*|WorkingDirectory=$SCRIPT_DIR/app_frontend|g" \
    -e "s|ExecStart=.*|ExecStart=$SCRIPT_DIR/app_frontend/bin/frontend|g" \
    "$SCRIPT_DIR/frontend.service" > "$TEMP_DIR/frontend.service"

# Copy service files
echo "Installing service files..."
sudo cp "$TEMP_DIR/probe.service" /etc/systemd/system/
sudo cp "$TEMP_DIR/frontend.service" /etc/systemd/system/

# Clean up temp files
rm -rf "$TEMP_DIR"

# Copy service files
echo "Copying service files..."
sudo cp /opt/net-pulse/probe.service /etc/systemd/system/
sudo cp /opt/net-pulse/frontend.service /etc/systemd/system/

# Reload systemd
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable services
echo "Enabling services..."
sudo systemctl enable probe.service
sudo systemctl enable frontend.service

# Start services
echo "Starting services..."
sudo systemctl start probe.service
sudo systemctl start frontend.service

# Check status
echo ""
echo "Service status:"
echo "==============="
sudo systemctl status probe.service --no-pager -l
echo ""
sudo systemctl status frontend.service --no-pager -l

echo ""
echo "Installation complete!"
echo ""
echo "Useful commands:"
echo "  sudo systemctl status probe.service     - Check probe status"
echo "  sudo systemctl status frontend.service  - Check frontend status"
echo "  journalctl -u probe.service -f          - Follow probe logs"
echo "  journalctl -u frontend.service -f       - Follow frontend logs"
echo "  sudo systemctl restart probe.service    - Restart probe"
echo "  sudo systemctl restart frontend.service - Restart frontend"

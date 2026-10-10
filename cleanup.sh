#!/bin/bash
set -e

JENKINS_DIR="$(dirname "$(readlink -f "$0")")"
JENKINS_HOME="$JENKINS_DIR/home"

# Stop and disable the service
sudo systemctl stop jenkins 2>/dev/null || true
sudo systemctl disable jenkins 2>/dev/null || true

# Remove the unit file
sudo rm -f /etc/systemd/system/jenkins.service
sudo rm -rf /etc/systemd/system/jenkins.service.d/
sudo systemctl daemon-reload

# Remove generated script
rm -f "$JENKINS_DIR/start-jenkins.sh"

# Remove project-local JENKINS_HOME
rm -rf "$JENKINS_HOME"

# Remove legacy ~/.jenkins (if it exists from a previous setup)
rm -rf "$HOME/.jenkins"

# Kill any stray java processes running jenkins.war
pkill -f "jenkins.war" 2>/dev/null || true

echo "Clean. Ready to retest:"
echo "  ./setup.sh && sudo systemctl start jenkins"   

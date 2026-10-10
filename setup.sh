#!/bin/bash
set -e

JENKINS_DIR="$(dirname "$(readlink -f "$0")")"
source "$JENKINS_DIR/.env"

JENKINS_HOME=$JENKINS_DIR/home
JENKINS_USER=$(whoami)

# Create directories
sudo mkdir -p "$JENKINS_DIR" "$JENKINS_HOME"
sudo chown -R "$JENKINS_USER:$JENKINS_USER" "$JENKINS_DIR"

# Create the wrapper script
sudo tee "$JENKINS_DIR/start-jenkins.sh" > /dev/null << 'EOF'
#!/bin/bash
set -e

JENKINS_DIR="$(dirname "$(readlink -f "$0")")"
source "$JENKINS_DIR/.env"

JENKINS_HOME="$JENKINS_DIR/home"

# Enable security on first run
if [ ! -f "$JENKINS_HOME/config.xml" ]; then
  mkdir -p "$JENKINS_HOME"
  cat > "$JENKINS_HOME/config.xml" << 'XMLEOF'
<?xml version='1.1' encoding='UTF-8'?>
<hudson>
  <useSecurity>true</useSecurity>
  <securityRealm class="hudson.security.LegacySecurityRealm">
    <delegate>true</delegate>
  </securityRealm>
  <authorizationStrategy class="hudson.security.LegacyAuthorizationStrategy"/>
</hudson>
XMLEOF
fi

java -Djenkins.install.runSetupWizard=false \
  -jar "$JENKINS_DIR/jenkins.war" \
  --argumentsRealm.passwd.$JENKINS_ADMIN_USER=$JENKINS_ADMIN_PASS \
  --argumentsRealm.roles.$JENKINS_ADMIN_USER=admin \
  --httpPort=$JENKINS_PORT &
JENKINS_PID=$!

for i in $(seq 1 60); do
  curl -s -o /dev/null http://localhost:$JENKINS_PORT/login && break
  sleep 2
  if [ $i -eq 60 ]; then
    echo "Jenkins failed to start within 120s" >&2
    exit 1
  fi
done

java -jar "$JENKINS_DIR/jenkins-cli.jar" -s http://localhost:$JENKINS_PORT/ \
  -auth $JENKINS_ADMIN_USER:$JENKINS_ADMIN_PASS install-plugin \
  $(curl -s https://raw.githubusercontent.com/jenkinsci/jenkins/master/core/src/main/resources/jenkins/install/platform-plugins.json \
    | jq -r '.[].plugins[] | select(.suggested==true) | .name' | tr '\n' ' ') || echo "Plugin install failed, continuing..."

wait $JENKINS_PID
EOF

sudo chmod +x "$JENKINS_DIR/start-jenkins.sh"

# Create the systemd unit file
sudo tee /etc/systemd/system/jenkins.service > /dev/null << EOF
[Unit]
Description=Jenkins CI
After=network.target

[Service]
Type=simple
User=$JENKINS_USER
Group=$JENKINS_USER
WorkingDirectory=$JENKINS_DIR
ExecStart=$JENKINS_DIR/start-jenkins.sh
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable
sudo systemctl daemon-reload
sudo systemctl enable jenkins

echo "Done. Ensure jenkins.war and jenkins-cli.jar are in $JENKINS_DIR, then:"
echo "sudo systemctl start jenkins"
echo "systemctl status jenkins" 

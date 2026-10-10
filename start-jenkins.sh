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

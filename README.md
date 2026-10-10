# Jenkins CI — Local Setup

Automated local Jenkins installation using jenkins.war with systemd, pre-configured security, and suggested plugin installation.

## Prerequisites

- Ubuntu (20.04+)
- Java 21 (OpenJDK)
- jq

Install:
sudo apt update && sudo apt install -y openjdk-21-jre jq

## Project Structure
```
jenkins/
├── .env                  # Credentials & port
├── jenkins.war           # Jenkins WAR file
├── jenkins-cli.jar       # Jenkins CLI
├── setup.sh              # One-time installer
├── cleanup.sh            # Full teardown
├── start-jenkins.sh      # Runtime script (generated)
└── home/                 # config.xml, plugins/, workspace/ etc. 
    ├── config.xml
    ├── plugins/
    ├── secrets/
    ├── jobs/
    │   └── my-job/
    │       ├── config.xml
    │       └── builds/
    └── workspace/
        └── my-job/
```

## Quick Start

wget https://get.jenkins.io/war-stable/latest/jenkins.war
wget https://get.jenkins.io/cli/jenkins-cli.jar
nano .env
./setup.sh
sudo systemctl start jenkins

Open http://localhost:8080 and log in with credentials from .env.

## Configuration

.env:
JENKINS_ADMIN_USER=admin
JENKINS_ADMIN_PASS=admin
JENKINS_PORT=8080

Restart after changes:
sudo systemctl restart jenkins

## Service Management

sudo systemctl start jenkins      # Start
sudo systemctl stop jenkins       # Stop
sudo systemctl restart jenkins    # Restart
systemctl status jenkins          # Status
journalctl -u jenkins -f          # Live logs
./cleanup.sh                      # Full teardown

## How It Works

1. setup.sh writes start-jenkins.sh and the systemd unit file, then enables the service.
2. On each start, start-jenkins.sh:
   - Sources .env for credentials and port
   - Writes config.xml with security enabled (first run only)
   - Starts Jenkins with setup wizard disabled
   - Waits for Jenkins to respond
   - Installs all currently suggested plugins via CLI
   - Stays alive as the parent process (systemd requirement)

## Retesting

./cleanup.sh
./setup.sh
sudo systemctl start jenkins

## Notes

- Running as your desktop user — fine for local dev, not production.
- --argumentsRealm flags only define credentials; security is enabled via pre-written config.xml.
- JENKINS_HOME is project-local (./home/), keeping everything in one folder.
- cleanup.sh also removes legacy ~/.jenkins if it exists.

#!/bin/bash
# CUPS Addon Startup Script for Home Assistant
# Handles D-Bus, Avahi, and CUPS initialization with persistent storage

set -e

# Get log level from options
LOG_LEVEL=${LOG_LEVEL:-"info"}

# Color output
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CUPS Print Server for Home Assistant${NC}"
echo -e "${GREEN}========================================${NC}"

# Create persistent data directories
echo -e "${YELLOW}Setting up persistent storage...${NC}"
mkdir -p /data/cups/ppd
mkdir -p /data/cups/classes
mkdir -p /data/cups/ssl
mkdir -p /data/avahi

# Setup symbolic links to persist configuration across restarts
echo -e "${YELLOW}Configuring symbolic links...${NC}"

# CUPS configuration symlinks
if [ -d /etc/cups/ppd ]; then
    rm -rf /etc/cups/ppd
fi
ln -sf /data/cups/ppd /etc/cups/ppd || true

# Link printers configuration (if it exists in data)
if [ -f /data/cups/printers.conf ]; then
    rm -f /etc/cups/printers.conf
    ln -sf /data/cups/printers.conf /etc/cups/printers.conf
fi

# Link classes configuration (if it exists in data)
if [ -f /data/cups/classes.conf ]; then
    rm -f /etc/cups/classes.conf
    ln -sf /data/cups/classes.conf /etc/cups/classes.conf
fi

# Ensure proper permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R root:lpadmin /etc/cups
chown -R root:lpadmin /data/cups
chmod 755 /etc/cups
chmod 755 /data/cups
chmod 710 /data/cups/ppd 2>/dev/null || true

# Initialize D-Bus
echo -e "${YELLOW}Starting D-Bus daemon...${NC}"
rm -f /run/dbus/pid 2>/dev/null || true
mkdir -p /run/dbus
chown messagebus:messagebus /run/dbus

if ! dbus-daemon --system --nofork --nopidfile &
then
    echo -e "${RED}Failed to start D-Bus${NC}"
    exit 1
fi

echo -e "${GREEN}D-Bus started successfully${NC}"
sleep 2

# Initialize Avahi daemon for mDNS/Bonjour discovery
echo -e "${YELLOW}Starting Avahi daemon...${NC}"
mkdir -p /var/run/avahi-daemon
chown avahi:avahi /var/run/avahi-daemon

# Create Avahi configuration if it doesn't exist
if [ ! -f /etc/avahi/avahi-daemon.conf ]; then
    cat > /etc/avahi/avahi-daemon.conf << 'EOF'
[General]
interfaces=
allow-interfaces=
denying-interfaces=
reuseaddr=yes
check-response-ttl=no
use-ipv4=yes
use-ipv6=yes
publish-addresses=yes
publish-hinfo=yes
publish-workstation=yes
publish-domain=yes
respect-effective-domain=no
allow-point-to-point=no
host-name=cups-server
domain-name=local
interfaces-mdns=
interfaces-non-mdns=
ttl=4500
delay-msec=215
cache-entries-max=4096
ratelimit-interval-usec=1000
ratelimit-burst=1000
logging=no
dump-db=no
dbfile=/var/lib/avahi/avahi.db
use-iff-running=no
disable-publishing=no
disable-user-service-publishing=no
publish-uname=no
publish-no-cookie=no
publish-addresses-no-ipv4=no
publish-addresses-no-ipv6=no
EOF
fi

if ! avahi-daemon --daemonize --no-rlimit --syslog 2>/dev/null
then
    echo -e "${YELLOW}Avahi daemon failed to start (non-critical)${NC}"
else
    echo -e "${GREEN}Avahi daemon started successfully${NC}"
fi

sleep 2

# Prepare CUPS configuration
echo -e "${YELLOW}Configuring CUPS daemon...${NC}"

# Ensure CUPS directories exist with correct permissions
mkdir -p /var/spool/cups
mkdir -p /var/cache/cups
mkdir -p /var/log/cups
mkdir -p /run/cups

chown -R root:lpadmin /var/spool/cups
chown -R root:lpadmin /var/cache/cups
chown -R root:lpadmin /var/log/cups
chown -R root:lpadmin /run/cups

chmod 755 /var/spool/cups
chmod 755 /var/cache/cups
chmod 755 /var/log/cups
chmod 755 /run/cups

# Copy CUPS configuration if not already present
if [ -f /etc/cups/cupsd.conf.default ]; then
    cp /etc/cups/cupsd.conf.default /etc/cups/cupsd.conf.bak 2>/dev/null || true
fi

# Start cupsd
echo -e "${YELLOW}Starting CUPS daemon...${NC}"

if cupsd -l
then
    echo -e "${GREEN}CUPS daemon started successfully${NC}"
else
    echo -e "${RED}Failed to start CUPS daemon${NC}"
    exit 1
fi

# Wait for CUPS to fully initialize
sleep 2

# Enable CUPS socket
echo -e "${YELLOW}Enabling CUPS socket...${NC}"
if ! /usr/sbin/cupsctl --share-printers --user-cancel-any --remote-admin --web-interface 2>/dev/null
then
    echo -e "${YELLOW}cupsctl command failed (non-critical)${NC}"
fi

# List USB devices for debugging
echo -e "${YELLOW}USB Devices detected:${NC}"
lsusb 2>/dev/null || echo "No USB devices found or lsusb not available"

# Check network connectivity
echo -e "${YELLOW}Network interfaces:${NC}"
if command -v ip &> /dev/null; then
    ip addr show 2>/dev/null || echo "Could not list IP addresses"
else
    ifconfig 2>/dev/null || echo "Could not list network configuration"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CUPS Server is running${NC}"
echo -e "${GREEN}Web Interface: http://$(hostname -I | awk '{print $1}'):631${NC}"
echo -e "${GREEN}mDNS Name: cups-server.local${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Log CUPS debug output
echo -e "${YELLOW}Starting CUPS log monitoring...${NC}"

# Keep the container running
while true
do
    # Check if cupsd is still running
    if ! pgrep -x "cupsd" > /dev/null
    then
        echo -e "${RED}CUPS daemon stopped unexpectedly${NC}"
        cupsd -l
    fi
    
    # Check if Avahi is still running
    if ! pgrep -x "avahi-daemon" > /dev/null
    then
        echo -e "${YELLOW}Avahi daemon stopped, attempting restart...${NC}"
        avahi-daemon --daemonize --no-rlimit --syslog 2>/dev/null || true
    fi
    
    sleep 30
done

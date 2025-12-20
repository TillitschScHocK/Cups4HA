#!/usr/bin/with-contenv bash

# Create CUPS data directories for persistence
mkdir -p /data/cups/cache
mkdir -p /data/cups/logs
mkdir -p /data/cups/state
mkdir -p /data/cups/config

# Set proper permissions
chown -R root:lp /data/cups
chmod -R 775 /data/cups

# Create CUPS configuration directory if it doesn't exist
mkdir -p /etc/cups

# Only create default cupsd.conf if it doesn't exist in persistent storage
if [ ! -f /data/cups/config/cupsd.conf ]; then
    echo "Creating default CUPS configuration..."
    cat > /data/cups/config/cupsd.conf << EOL
# Listen on all interfaces
Listen 0.0.0.0:631

# Allow access from local network
<Location />
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>

# Admin access (no authentication)
<Location /admin>
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>

# Job management permissions
<Location /jobs>
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Location>

<Limit Send-Document Send-URI Hold-Job Release-Job Restart-Job Purge-Jobs Set-Job-Attributes Create-Job-Subscription Renew-Subscription Cancel-Subscription Get-Notifications Reprocess-Job Cancel-Current-Job Suspend-Current-Job Resume-Job Cancel-My-Jobs Close-Job CUPS-Move-Job CUPS-Get-Document>
  Order allow,deny
  Allow localhost
  Allow 10.0.0.0/8
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
</Limit>

# Enable web interface
WebInterface Yes

# Default settings
DefaultAuthType None
JobSheets none,none
PreserveJobHistory No
EOL
fi

# Copy all existing persistent configuration files to /etc/cups
echo "Loading persistent CUPS configuration from /data/cups/config..."
if [ -d "/data/cups/config" ]; then
    # Copy all config files from persistent storage
    cp -f /data/cups/config/* /etc/cups/ 2>/dev/null || true
fi

# Ensure critical files exist
touch /etc/cups/printers.conf
touch /etc/cups/classes.conf
touch /etc/cups/subscriptions.conf

# Set proper permissions for CUPS config files
chown -R root:lp /etc/cups
chmod 640 /etc/cups/cupsd.conf
chmod 600 /etc/cups/printers.conf 2>/dev/null || true
chmod 600 /etc/cups/classes.conf 2>/dev/null || true
chmod 600 /etc/cups/subscriptions.conf 2>/dev/null || true

echo "CUPS configuration loaded successfully."

# Start CUPS service
/usr/sbin/cupsd -f
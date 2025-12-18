# Use Debian-based HA Addon base image for better driver compatibility
FROM ghcr.io/hassio-addons/debian-base:latest

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV CUPS_LOG_LEVEL=warn

# Install system dependencies and CUPS
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Core CUPS packages
    cups \
    cups-client \
    cups-filters \
    cups-daemon \
    \
    # Driver packages for broad compatibility
    foomatic-db-compressed-ppds \
    printer-driver-all \
    printer-driver-gutenprint \
    openprinting-ppds \
    hplip \
    hplip-data \
    \
    # Avahi/mDNS for network discovery and AirPrint
    avahi-daemon \
    avahi-utils \
    libnss-mdns \
    \
    # D-Bus for printer management
    dbus \
    dbus-x11 \
    \
    # USB utilities for debugging
    usbutils \
    lsb-release \
    \
    # Additional utilities
    curl \
    wget \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Create necessary directories
RUN mkdir -p /run/dbus \
    && mkdir -p /var/spool/cups \
    && mkdir -p /var/cache/cups \
    && mkdir -p /var/log/cups \
    && mkdir -p /etc/cups/ppd \
    && mkdir -p /data/cups \
    && mkdir -p /data/cups/ppd \
    && mkdir -p /data/cups/classes \
    && mkdir -p /data/cups/ssl

# Copy custom CUPS configuration
COPY cupsd.conf /etc/cups/cupsd.conf

# Set proper permissions for CUPS
RUN chmod 755 /var/spool/cups \
    && chmod 755 /var/cache/cups \
    && chown -R root:lpadmin /etc/cups \
    && chmod 755 /etc/cups

# Copy startup script
COPY run.sh /
RUN chmod +x /run.sh

CMD [ "/run.sh" ]

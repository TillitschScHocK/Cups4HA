# CUPS Addon - Technische Dokumentation

Dokumentiert die technischen Implementierungsdetails des CUPS Addons.

## Architektur

### Container Structure

```
Docker Container (Debian Base)
├── CUPS Daemon (cupsd)
│   ├── IPP Protocol Server (Port 631)
│   ├── Web Interface (Port 631)
│   └── PPD Drivers Management
├── Avahi Daemon
│   ├── mDNS Broadcasting
│   ├── Service Registration
│   └── Device Discovery
├── D-Bus System Bus
│   ├── IPC Management
│   └── Device Communication
├── Device Drivers
│   ├── Foomatic Database
│   ├── HP-LIP (HPLIP)
│   ├── Gutenprint
│   └── OpenPrinting PPDs
└── System Services
    ├── syslog-ng (optional)
    └── Hardware detection
```

## Port-Mapping

| Port | Protokoll | Zweck | Mode |
|------|-----------|-------|---------|
| 631 | TCP | CUPS Web UI & IPP | Bidirectional |
| 631 | UDP | CUPS Broadcasting | Bidirectional |
| 8631 | TCP | CUPS Secure (HTTPS) | Bidirectional |
| 5353 | UDP | mDNS/Avahi | Bidirectional |

## Volume Mapping

### Home Assistant Data Directory `/data`

```
/data/cups/
├── ppd/                  # Printer Description Files
│   ├── HP-LaserJet.ppd
│   ├── Canon-Pixma.ppd
│   └── ...
├── printers.conf         # CUPS Printers Configuration
├── classes.conf          # Printer Classes Configuration
├── subscriptions.conf    # Event Subscriptions
└── ssl/                  # SSL Certificates
    ├── server.crt
    ├── server.key
    └── client.crt
```

### Symlink Strategy

Das `run.sh` Script erstellt Symlinks für Persistenz:

```bash
# /etc/cups/ppd -> /data/cups/ppd
ln -sf /data/cups/ppd /etc/cups/ppd

# /etc/cups/printers.conf -> /data/cups/printers.conf (falls existent)
ln -sf /data/cups/printers.conf /etc/cups/printers.conf
```

## Netzwerk-Konfiguration

### Host Network Mode

```yaml
host_network: true  # in config.yaml
```

Gründe für Host Network Mode:

1. **mDNS/Avahi Broadcasting**: Erfordert UDP Port 5353 Broadcast
2. **Drucker-Discovery**: mDNS Queries brauchen direkte Netzwerk-Access
3. **AirPrint Support**: iOS/macOS brauchen mDNS für Discovery
4. **Netzwerk-Printers**: LAN-Drucker brauchen direkten Access

Alternative wäre komplexes Port-Mapping für jeden Port nötig.

### USB Device Mapping

```yaml
privileged: true
devices:
  - "/dev/bus/usb:/dev/bus/usb:rwm"
```

Gewährt Root-Zugriff auf:
- USB-Bus enumeration
- Device descriptor reading
- Printer communication

## CUPS Konfiguration

### cupsd.conf Highlights

```conf
# Listen auf allen Interfaces
Listen 0.0.0.0:631
Listen [::]:631
Listen /run/cups/cups.sock

# Netzwerk-Druckersharing
Sharing Yes
SharePrinters Yes
UserPrinterSharing Yes

# Standardauthentifizierung (lokal, keine Passwort)
DefaultAuthType None

# Zugriff für lokale Netzwerke
<Location />
  Order allow,deny
  Allow 127.0.0.1
  Allow 172.16.0.0/12
  Allow 192.168.0.0/16
  Allow 10.0.0.0/8
</Location>
```

## Avahi-Dienste

### Automatische Service Registration

Avahi registriert automatisch:

```
Service: _ipp._tcp
Service: _ipps._tcp (wenn SSL enabled)
Service: _http._tcp
Domain: local
Name: CUPS Print Server [Hostname]
```

### mDNS/Bonjour Broadcasting

Druckerfunktionalität wird als mDNS-Service veröffentlicht:

```
_cups._tcp.local
_ipp._tcp.local
_printer._tcp.local
_airprint._tcp.local (bei aktiven AirPrint-Druckern)
```

## D-Bus Integration

### System Bus

CUPS nutzt D-Bus für:

1. **Printer Discovery**: HAL/udev device notifications
2. **Power Management**: Sleep/Wake events
3. **User Session Management**: User login/logout events
4. **System Services**: Communication mit anderen Daemons

### D-Bus Socketanforderungen

```
/run/dbus/system_bus_socket  # System Bus
/run/dbus/session_bus        # Session Bus (optional)
```

## USB Printer Detection

### Hotplug-Handling

```bash
# USB Device VendorID:ProductID
BUS 001 Device 005: ID 03f0:0c17 Hewlett-Packard

# CUPS erkennt automatisch:
# 1. Device connected (udev event)
# 2. Queried device info
# 3. Matched against known driver database
# 4. Registered as available printer
```

### Unterstutzte Printer Classes

```
HP LaserJet/OfficeJet/Photosmart
Canon PIXMA/imageCLASS
Epson WorkForce/Expression
Brother HL/MFC
Xerox VersaLink/AltaLink
Ricoh MP/SP Series
Kyocera ECOSYS
Konica Minolta Bizhub
OKI C/MC Series
```

## Driver Management

### PPD (PostScript Printer Description) Files

```
/etc/cups/ppd/          # CUPS PPD Directory
/usr/share/ppd/         # System PPD Database
/data/cups/ppd/         # Persistent PPD Storage
```

### Foomatic-Integration

```bash
# Foomatic Database (komprimiert)
foomatic-db-compressed-ppds

# Enthält:
# - 1000+ printer models
# - Multiple driver support per printer
# - Automatic driver selection
```

### HP-LIP (HPLIP) Spezielle Unterstützung

```
hplip-x.y.z
├── hpcups           # HP CUPS Backend
├── hpijs            # HP IJS Backend
├── hp-plugin        # Proprietary plugins
├── Scan support
└── Device management
```

## Druckauftrag-Verarbeitung

### IPP (Internet Printing Protocol) Workflow

```
1. Client verbindet sich zu Port 631 (TCP)
2. IPP-Request wird gesendet
3. CUPS parsed den Request
4. Job wird erstellt und in Queue eingefüt
5. Scheduler wählt Drucker und Filter
6. Filter konvertiert zu Druckerformat
7. Daten werden an Drucker gesendet
8. Job-Status wird aktualisiert
```

### Filter Pipeline

```
Input PDF
    ↓
[PDF -> PS Converter]
    ↓
PostScript
    ↓
[PS -> Printer Format Converter]
    ↓
Printer Native Format (PCL, PJL, etc)
    ↓
Printer
```

## Persistenz-Mechanismus

### Configuration Backup/Restore

```bash
# Beim Starten
1. Prüfe /data/cups/ auf existierende Konfiguration
2. Falls vorhanden: Stelle Symlinks her
3. Falls neu: Initialisiere von Default-Dateien

# Beim Herunterfahren
1. CUPS speichert aktuelle Konfiguration
2. Daten bleiben in /data/cups/ erhalten
3. Nächster Start lädt gespeicherte Konfiguration
```

### File Permissions

```
/data/cups/ppd/        755  (drwxr-xr-x)  root:lpadmin
/data/cups/printers.conf  644  (-rw-r--r--)  root:lpadmin
/etc/cups/              755  (drwxr-xr-x)  root:lpadmin
/var/spool/cups/       755  (drwxr-xr-x)  root:lpadmin
```

## Logging

### CUPS Log Dateien

```
/var/log/cups/
├── access_log       # HTTP Access Log
├── error_log        # CUPS Error/Debug Log
├── page_log         # Page Accounting
└── audit_log        # Security Audit (optional)
```

### Log Level Configuration

```conf
# cupsd.conf
LogLevel warn        # warn, info, debug
```

Optionen:
- `error`: Nur Fehler
- `warn`: Fehler und Warnungen
- `info`: Informationen
- `debug`: Detailliertes Debugging

## Performance Tuning

### CUPS Daemon Parameters

```conf
MaxClients 100              # Max gleichzeitige Verbindungen
MaxClientsPerHost 10        # Max pro Host
Timeout 300                 # Connection Timeout (Sekunden)
KeepAlive Yes              # HTTP Keep-Alive
KeepAliveTimeout 60        # Keep-Alive Timeout
```

### Memory Management

```
Kleine Installationen: 150-200 MB
Mittlere Installation: 200-300 MB
Große Installation: 300+ MB
```

## Security Considerations

### Netzwerk-Sicherheit

```
1. Host Network Mode erfordert vertrauenswürdiges lokales Netzwerk
2. No IPP-over-HTTPS validation
3. DefaultAuthType None = Offene Authentifizierung
```

### Privileg-Escalation

```
privileged: true erlaubt:
- USB device access
- Network interface access
- System configuration
```

### Sicherheits-Empfehlungen

1. **Nur im lokalen Netzwerk verwenden**
2. **Port 631 nicht nach außen exposen**
3. **Reguläre Sicherheitsupdates**
4. **Firewall-Regeln für Port 631**

## Debugging

### CUPS Debug Mode

```bash
# Terminal im Container
docker exec addon_cups_cups /bin/bash

# CUPS in Debug Mode starten
cupsd -d

# Logs folgen
tail -f /var/log/cups/error_log
```

### Netzwerk Debugging

```bash
# mDNS Services zeigen
avahi-browse -a

# Network-Interfaces prüfen
ip addr show

# CUPS Socket prüfen
ss -tlnp | grep 631
```

### Drucker-Debugging

```bash
# Drucker auflisten
lpstat -p -d

# Queue Details
lpq -P PrinterName

# Drucker-Tests
lpstat -t
```

## Bekannte Probleme

### Problem: Avahi startet nicht

**Ursache**: D-Bus nicht ready  
**Lösung**: Weitere Verzögerung in run.sh

### Problem: USB-Drucker nicht erkannt

**Ursache**: `/dev/bus/usb` nicht gemappt  
**Lösung**: `privileged: true` und devices in config.yaml

### Problem: CUPS antwortet nicht

**Ursache**: Port 631 nicht gebunden  
**Lösung**: Host Network Mode prüfen, Logs anschauen

## Future Improvements

1. **Samba/SMB Backend**: Windows printer sharing
2. **Scan Support**: Document scanning via SANE
3. **Web-based UI**: Erweiterte Web-Schnittstelle
4. **Metrics**: Prometheus metrics export
5. **IPP-over-USB**: Direct USB printing
6. **Mobile App**: Native Home Assistant integration

## Referenzen

- [CUPS Documentation](https://www.cups.org/doc/)
- [Avahi mDNS](https://avahi.org/)
- [D-Bus System](https://dbus.freedesktop.org/)
- [IPP RFC 8010](https://tools.ietf.org/html/rfc8010)
- [AirPrint Technical Specification](https://support.apple.com/en-us/HT201311)

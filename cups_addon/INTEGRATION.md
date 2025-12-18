# CUPS Addon Integration Guide

Diese Dokumentation beschreibt, wie das CUPS Addon mit anderen Home Assistant Komponenten integriert wird.

## WebRTC/MJPEG-Kamera Integration

Das CUPS Addon kann mit Kameras verbunden werden, um gedruckte Bilder anzuzeigen oder zu speichern.

```yaml
# Beispiel: Bilder drucken von Sicherheitskameras
automation:
  - alias: "Drucker Snapshot bei Bewegung"
    trigger:
      platform: state
      entity_id: binary_sensor.front_door_motion
      to: "on"
    action:
      service: shell_command.print_camera_snapshot
      data:
        camera_id: "camera.front_door"
```

## SSH Integration

Remote-Zugriff auf CUPS über SSH:

```bash
# Drucker auflisten
ssh root@HOMEASSISTANT_IP
docker exec addon_cups_cups lpstat -p

# Drucker hinzufügen (remote)
docker exec addon_cups_cups lpadmin -p HP -m drv:///sample.drv/generic.ppd -E

# Druckauftrag senden
rsh root@HOMEASSISTANT_IP 'docker exec addon_cups_cups lp -d HP /path/to/file.pdf'
```

## REST API Integration

Zu drucken über REST API in Home Assistant:

```yaml
shell_command:
  print_file: 'curl -X POST http://127.0.0.1:631/admin/printer -F "printer_name=HP" -F "file=@{{ file_path }}"'
  
  get_printers: 'curl http://127.0.0.1:631/admin/printers'
```

## Command Line Sensor

Überwachen des Druckers durch Sensoren:

```yaml
sensor:
  - platform: command_line
    name: "CUPS Status"
    command: 'curl -s http://127.0.0.1:631/admin/printers | grep -o "<printer>.*</printer>" | wc -l'
    unit_of_measurement: "Drucker"
    scan_interval: 300
```

## Automation Beispiele

### Tägliche Druckerverwaltung

```yaml
automation:
  - alias: "Täglicher Drucker-Health-Check"
    trigger:
      platform: time
      at: "08:00:00"
    action:
      - service: shell_command.check_printer_status
      - service: notify.push_notification
        data:
          message: "Drucker-Status überprüft"
```

### Drucken von Sensordaten

```yaml
automation:
  - alias: "Wöchentlicher Bericht drucken"
    trigger:
      platform: time
      at: "20:00:00"
      weekday:
        - fri
    action:
      - service: shell_command.generate_and_print_report
```

## Samba/SMB Integration (optional)

Wenn `enable_samba: true` aktiviert ist:

```bash
# Windows/Linux SMB-Zugriff
\\HOMEASSISTANT_IP\CUPS
```

## IPP Printing Protocol

Direkte IPP-Druckaufträge:

```bash
# IPP Print
ipp://HOMEASSISTANT_IP:631/printers/PrinterName

# Beispiel mit lp-Befehl
lp -h HOMEASSISTANT_IP -d PrinterName file.pdf
```

## AirPrint Integration (macOS/iOS)

AirPrint funktioniert automatisch mit Avahi:

1. Drucker erscheint in Druckerliste auf Mac/iPhone
2. Wählen Sie "CUPS Print Server - [PrinterName]"
3. Druckoptionen wie gewohnt setzen
4. Auf Drucken klicken

## Network Printing Integration (Windows)

Direkte Netzwerk-Druckerinstallation:

```
1. Systemsteuerung → Geräte und Drucker
2. Drucker hinzufügen
3. Netzwerk-, Bluetooth- oder RF-Drucker
4. URL eingeben: ipp://HOMEASSISTANT_IP:631/
5. Automatische Treiberinstallation folgt
```

## MQTT Integration

Druckerstatus über MQTT veröffentlichen:

```yaml
shell_command:
  publish_printer_status: |
    STATUS=$(curl -s http://127.0.0.1:631/admin/printers)
    mosquitto_pub -h mqtt_server -t "cups/status" -m "$STATUS"

automation:
  - alias: "Druckerstatus an MQTT"
    trigger:
      platform: time_pattern
      minutes: "/5"
    action:
      service: shell_command.publish_printer_status
```

## Scripting Integration

### Python Integration

```python
import cups

conn = cups.Connection(host='127.0.0.1', port=631)
printers = conn.getPrinters()
for printer_name, printer_info in printers.items():
    print(f"Printer: {printer_name}")
    print(f"  Status: {printer_info['printer-state']}")
```

### JavaScript/Node.js Integration

```javascript
const http = require('http');

const options = {
  hostname: 'homeassistant_ip',
  port: 631,
  path: '/admin/printers',
  method: 'GET'
};

const req = http.request(options, (res) => {
  console.log(`STATUS: ${res.statusCode}`);
});

req.end();
```

## Docker Integration

Direkte Kommunikation mit dem CUPS Container:

```bash
# In Home Assistant Terminal

# Drucker auflisten
docker exec addon_cups_cups lpstat -p

# Cups-Dienst neu starten
docker exec addon_cups_cups systemctl restart cups

# In Logs schauen
docker logs addon_cups_cups
```

## Performance Optimization

### Drucker-Caching

Drucker-Liste wird automatisch zwischengespeichert (300 Sekunden):

```yaml
sensor:
  - platform: command_line
    name: "CUPS Status"
    command: 'curl -s http://127.0.0.1:631/admin/printers'
    scan_interval: 300  # Nur alle 5 Minuten abfragen
```

### Batch Printing

Mehrere Dateien auf einmal drucken:

```bash
for file in *.pdf; do
  lp -h 127.0.0.1 -d HP "$file"
done
```

## Sicherheit

### Lokal Netzwerk Restricted

Zugriff auf lokale Netzwerk-IPs begrenzen:

```bash
# Im CUPS Config
cupsctl --remote-admin-access --share-printers
```

### Firewall Regeln

Nur von lokalen IPs erlauben:

```yaml
# Home Assistant firewall (falls vorhanden)
ports:
  631/tcp: "Allow internal only"
  631/udp: "Allow internal only"
```

## Troubleshooting

### Verbindung fehlgeschlagen

```bash
# Test connection
curl -v http://127.0.0.1:631/

# Prüfe Port
netstat -tlnp | grep 631
```

### Drucker nicht erkannt

```bash
# Avahi debug
avahi-browse -a

# CUPS debug
cupsd -d  # Debug mode
```

## Support

Bei Integrationsproblemen:
1. Logs anschauen (`docker logs addon_cups_cups`)
2. GitHub Issues erstellen
3. Home Assistant Community Forum nutzen

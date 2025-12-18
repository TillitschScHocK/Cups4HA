# CUPS Print Server Addon - Changelog

## [1.0.0] - 2025-01-01

### Added
- Initial release of CUPS Print Server addon for Home Assistant
- Full CUPS daemon with network printer support
- Avahi daemon for mDNS/Bonjour discovery
- AirPrint support for iOS/macOS devices
- USB printer detection and support
- Web interface for printer management (port 631)
- D-Bus integration for printer management
- Persistent storage for printer configurations
- Support for all major printer brands (HP, Canon, Epson, Brother, etc.)
- Comprehensive driver support (foomatic, gutenprint, hplip)
- Automatic printer discovery on local network
- Multi-architecture support (aarch64, amd64, armhf, armv7, i386)
- Detailed logging and debugging capabilities
- Complete README with troubleshooting guide

### Features
- Host network mode for mDNS/Bonjour broadcasting
- Privileged container access for USB device mapping
- Automatic Avahi daemon management
- Automatic D-Bus session management
- Configuration symlinks for persistent printer data
- Health check and auto-restart capabilities
- Debug output for USB device detection
- Network interface information for troubleshooting

### Dependencies
- CUPS (Common Unix Printing System)
- CUPS Filters
- Avahi Daemon
- D-Bus
- HPLIP (HP Linux Imaging and Printing)
- Foomatic
- Gutenprint
- OpenPrinting PPDs
- usbutils

### Configuration Options
- `log_level`: Set logging verbosity (debug, info, warning, error)
- `enable_airprint`: Enable/disable AirPrint support (default: true)
- `enable_samba`: Enable/disable Samba printer sharing (default: false)

### Known Limitations
- Scanning functionality not supported (printing only)
- Some proprietary printer models may require additional drivers
- Network security features are minimal (local network focused)
- Some HP printers may need additional firmware updates

### Future Improvements (Planned)
- Samba/SMB printer sharing integration
- Scan support with document management
- Web-based driver installation
- LDAP/Active Directory authentication
- IPP-over-USB support
- Metrics and statistics tracking
- Mobile app integration

### Bug Fixes
- None in initial release

### Performance
- RAM Usage: 150-300 MB typical
- CPU Usage: <5% in idle state
- Disk Usage: ~500 MB for base installation
- Network Bandwidth: Minimal, only when printing

### Installation
1. Add repository to Home Assistant
2. Search for "CUPS Print Server"
3. Install addon
4. Start addon
5. Access web interface at http://[HA-IP]:631

### Support
For issues and feature requests, visit:
https://github.com/TillitschScHocK/Cupy4HA/issues

### License
MIT License

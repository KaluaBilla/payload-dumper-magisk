# Payload Dumper - Magisk Module

A Magisk module that provides payload dumper directly on rooted Android device.

## Features

This module packages two payload dumper implementations:

1. **[payload-dumper-rust](https://github.com/rhythmcache/payload-dumper-rust)** - Rust implementation
   - Direct extraction from URL
   - Metadata extraction support
   - Fast and memory efficient

2. **[payload-dumper-go](https://github.com/ssut/payload-dumper-go)** - Go implementation
   - Reliable and well-tested

## Installation

1. Download the latest release from [Releases](https://github.com/KaluaBilla/payload-dumper-magisk/releases)
2. Install via Magisk Manager
3. **Interactive Selection:** During installation, use volume keys to choose:
   - **Rust only** - Installs as `payload_dumper`
   - **Go only** - Installs as `payload_dumper`
   - **Both** - Installs as `payload_dumper_rust` and `payload_dumper_go`
   
   **Controls:**
   - **Volume DOWN** - Cycle through options
   - **Volume UP** - Confirm selection
   - **No input (10s)** - Auto-defaults to "Both"

4. Reboot your device

## 🔧 Usage

The command depends on what you installed:

### If you installed **Rust only** or **Go only**:
```bash
payload_dumper [options] <payload.bin>
```

### If you installed **Both**:
```bash
# Use Rust version
payload_dumper_rust [options] <payload.bin>

# Use Go version
payload_dumper_go [options] <payload.bin>
```

### Example Commands:
```bash
# Extract payload.bin
payload_dumper /sdcard/Download/payload.bin

# Rust: Extract from URL (if installed)
payload_dumper_rust https://example.com/ota.zip

# Extract specific partition
payload_dumper --partitions system,vendor payload.bin
```

For detailed usage instructions and available options, refer to the respective repositories:
- [payload-dumper-rust documentation](https://github.com/rhythmcache/payload-dumper-rust#readme)
- [payload-dumper-go documentation](https://github.com/ssut/payload-dumper-go#readme)



## License

This module is licensed under Apache License 2.0.

**Original Projects:**
- [payload-dumper-rust](https://github.com/rhythmcache/payload-dumper-rust) - Apache License 2.0
- [payload-dumper-go](https://github.com/ssut/payload-dumper-go) - Apache License 2.0

All rights reserved to the original authors. This repository only provides the Magisk module packaging.

## Credits

- [rhythmcache](https://github.com/rhythmcache) - payload-dumper-rust
- [ssut](https://github.com/ssut) - payload-dumper-go

## Disclaimer

This is an unofficial Magisk module. Use at your own risk. Always backup your data before installing any modules.

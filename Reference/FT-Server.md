# Flaschen Taschen Server Architecture

## Overview
The FT server is a network-connected LED display controller that receives pixel data over UDP and renders it on a physical LED matrix. It's designed to be backend-agnostic (hardware/terminal/simulation).

## Network Protocols

### 1. Main Protocol: PPM over UDP (Port 1337)
**Primary data channel** for pixel display updates.

- **Port**: 1337 (UDP)
- **Format**: PPM (Portable PixMap) binary format + FT extensions
- **Transport**: Single UDP datagram per frame
- **Frame Structure**:
  ```
  [PPM Header] [Color Data] [FT Metadata]
  - Width/Height (PPM binary format)
  - RGB pixel data (24-bit color)
  - X/Y offset (image placement on display)
  - Z-offset/Layer ID (layering support)
  - Layer timeout (auto-clear overlay after inactivity)
  ```

### 2. Network Discovery: PixelPusher Protocol
**Makes the server discoverable on the network**.

- **Discovery Port**: 7331 (UDP, broadcast)
- **Listen Port**: 5078 (TCP/UDP)
- **Protocol**: Universal Discovery Protocol (developed by Jas Strong & Jacob Potter)
- **Discovery Mechanism**:
  1. Server broadcasts discovery packets on UDP port 7331
  2. Clients listening on port 7331 receive discovery information
  3. Includes MAC address, IP, device type, hardware/software revision
  4. Allows clients to auto-detect available display servers

**Discovery Packet Contents** (`DiscoveryPacket` struct):
```c
- MAC Address (6 bytes)
- IP Address (4 bytes, network byte order)
- Device Type (ETHERDREAM, LUMIABRIDGE, PIXELPUSHER)
- Protocol Version
- Vendor/Product IDs
- Hardware/Software Revision
- Link Speed (bits per second)
- Device-specific data (PixelPusher/EtherDream/Lumia)
```

## Layering System

The server supports **16 independent layers** for compositing:
- **Layer 0**: Background (permanent)
- **Layers 1-15**: Overlays with automatic garbage collection
- **Transparency**: Black pixels (RGB 0,0,0) in overlay layers = transparent
- **Z-ordering**: Higher layer numbers appear on top
- **Auto-timeout**: Inactive overlays auto-clear after configurable timeout (default: 15 seconds)

**Use Case**: Multiple applications can send content simultaneously; overlays automatically clear without explicit removal commands.

## Server Initialization

**Command Line Options**:
```bash
./ft-server [options]

-D <width>x<height>     : Output resolution (default: 45x35)
--layer-timeout <sec>   : Overlay timeout in seconds (default: 15, min: 1)
-d                      : Become daemon (background process)
--hd-terminal           : Higher resolution terminal display mode
```

**Startup Sequence** (from main.cc):
1. Parse command-line options
2. Create display backend (hardware, RGB matrix, or terminal)
3. Initialize UDP server on port 1337 → returns early on bind failure
4. Daemonize if requested (`-d` flag)
5. Start display rendering thread
6. Initialize composite layering engine with garbage collection
7. Drop privileges (if running as root)
8. Block on `udp_server_run_blocking()` (handles all incoming packets)

## Backend Types

The server can target different display types via compile-time flags:

1. **Hardware** (`FT_BACKEND=ft`): Real Flaschen Taschen LED matrix
   - Requires root (GPIO access), drops privileges to `daemon:daemon`
   - Connects to spixels library for LED strip control
   - Configuration hardcoded in main.cc (column assembly, SPI ports)

2. **RGB Matrix** (`FT_BACKEND=1`): RGB LED matrix display
   - For Raspberry Pi with RGB matrix connected
   - Passes through rpi-rgb-led-matrix flags

3. **Terminal** (`FT_BACKEND=2`): ANSI color terminal display
   - For development without hardware
   - 24-bit color ANSI support (xterm, iTerm2, Linux terminals)
   - Optional HD mode with 2x resolution

## Key Implementation Details

### UDP Server (pixel-push-server.cc & udp-server.cc)
- Non-blocking socket for high-performance data reception
- Handles PixelPusher discovery broadcasts
- Validates packet sizes (max 65507 bytes)
- Thread-safe delivery to composite display layer

### Composite Display Engine (composite-flaschen-taschen.h)
- Manages layer stack and z-ordering
- Thread-safe rendering pipeline
- Garbage collection thread for expired overlays
- Efficient layer composition on each frame update

### PPM Reader (ppm-reader.cc)
- Parses binary PPM headers
- Extracts RGB pixel data
- Handles FT metadata extensions (offsets, layer info)

## Thread Safety & Real-time Considerations

- **Mutexes**: Core mutex for layer access (ft::Mutex)
- **Layer Garbage Collection**: Runs in separate thread, respects timeout
- **Real-time Priorities**: Threads can be configured with RT priorities
- **Privilege Dropping**: After hardware init, privileges dropped to non-root `daemon` user

## Network Discoverability Summary

| Protocol | Port | Type | Purpose |
|----------|------|------|---------|
| PPM over UDP | 1337 | UDP | Pixel data (main data channel) |
| PixelPusher Discovery | 7331 | UDP Broadcast | Device discovery |
| PixelPusher Protocol | 5078 | TCP/UDP | Alternative protocol support |

**Key Point**: By implementing the Universal Discovery Protocol, the FT server broadcasts its presence on port 7331, allowing network clients to auto-discover available display servers.

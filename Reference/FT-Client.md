# Flaschen Taschen Client Implementation Guide

## Overview
A Flaschen Taschen client is any application that sends pixel data to the FT server via UDP. Clients are simple and stateless—they create a framebuffer, set pixels, and send it over the network.

## Core Protocol

### UDP Packet Format
The FT server listens on **UDP port 1337** for PPM (Portable PixMap) format image data. Each Send() operation sends a complete image in a single UDP datagram.

**Packet Structure:**
```
[PPM Header (text)] [Binary RGB Data] [Optional FT Metadata]
```

### PPM Header Format
```
P6                    # Magic number (binary PPM)
<width> <height>      # Decimal ASCII numbers
#FT: <x> <y> <z>     # Optional metadata (must start with #FT:)
255                   # Max color value (fixed)
<binary RGB data>     # 3 bytes per pixel (R, G, B)
```

### Metadata: Offsets
FT extends PPM with optional metadata specifying where and how the image displays:

- **`#FT: x y z`** in header OR `x`, `y`, `z` on separate lines after RGB data
- **x offset**: Horizontal position (0 = left edge)
- **y offset**: Vertical position (0 = top edge)
- **z offset (layer)**: 0 = background, 1-15 = overlays
  - Layer 0 black pixels = opaque
  - Layers 1-15: black pixels = transparent
  - Auto-clears after `--layer-timeout` (default: 15 seconds)

**Example: 10×10 red image at position (5, 8), layer 2:**
```
P6
10 10
#FT: 5 8 2
255
<300 bytes RGB data: all pixels = 255,0,0>
```

## Client Implementation Approaches

### 1. Command-Line Tools (Bash/POSIX)
**Simplest approach** - pipe image tools to UDP socket.

```bash
# Send scaled JPEG to server
jpegtopnm image.jpg | pnmscale -xysize 45 35 | socat STDIO UDP-SENDTO:localhost:1337

# Or use bash's /dev/udp (if available)
cat image.ppm > /dev/udp/localhost/1337
```

**Pros:** No programming required, works with standard tools
**Cons:** Limited real-time control, image format conversion overhead

### 2. C++ API (`udp-flaschen-taschen.h`)
**Full-featured** client library with compositing, layers, and real-time control.

```cpp
#include "udp-flaschen-taschen.h"

// Open socket (auto-discovers server or uses FT_DISPLAY env var)
int socket = OpenFlaschenTaschenSocket("localhost");

// Create framebuffer
UDPFlaschenTaschen canvas(socket, 45, 35);

// Draw
canvas.SetPixel(0, 0, Color(255, 0, 0));   // Red pixel at origin
canvas.SetPixel(5, 5, Color(0, 0, 255));   // Blue pixel

// Layer support
canvas.SetOffset(10, 20, 2);  // Position (10,20), layer 2
canvas.Send();

// Optional: Configure for network (OSX has ~9KB limit)
canvas.SetMaxUDPPacketSize(9000);

// Clear screen
canvas.Clear();
canvas.Send();
```

**C++ API Methods:**
- `SetPixel(x, y, color)` - Set single pixel
- `GetPixel(x, y)` - Read pixel (for double-buffering)
- `Send()` - Transmit framebuffer
- `SetOffset(x, y, z)` - Position and layer
- `Clear()` - Fill with black
- `Fill(color)` - Fill with color
- `Clone()` - Copy framebuffer
- `SetMaxUDPPacketSize(size)` - Configure UDP size

**Pros:** Type-safe, compositing, layer support, pixel queries
**Cons:** Requires C++ compiler, linked against FT API library

### 3. Python API (`flaschen.py`)
**High-level, interactive** approach with minimal setup.

```python
import flaschen

# Create client
ft = flaschen.Flaschen("localhost", 1337, 45, 35)

# Draw pixels
for y in range(ft.height):
    for x in range(ft.width):
        ft.set(x, y, (255, 0, 0))  # Red

ft.send()  # Transmit

# Optional: Set offset/layer
ft.set_offset(10, 20, 2)
ft.send()
```

**Pros:** Simple syntax, easy for prototyping, good for animations
**Cons:** Slower than C++, requires Python runtime

### 4. Custom Implementation (Any Language)
**Raw UDP sender** - construct packets directly in your language.

**Pseudocode:**
```
1. Create buffer: [PPM header] + [RGB data]
2. Build header:
   - "P6\n"
   - "45 35\n"
   - "#FT: 0 0 0\n" (or omit for no offset)
   - "255\n"
3. Append 3 bytes per pixel (R, G, B)
4. Send UDP datagram to server_ip:1337
```

**Swift Implementation** (for macOS client like this project):
```swift
// Build PPM header
let header = "P6\n45 35\n#FT: 0 0 0\n255\n"
var packet = header.data(using: .utf8)!

// Append RGB data (45 * 35 * 3 bytes)
for pixel in pixels {
    packet.append(contentsOf: [pixel.r, pixel.g, pixel.b])
}

// Send via UDP
let endpoint = NWEndpoint.hostPort(host: "localhost", port: 1337)
connection.send(content: packet, completion: .idempotent)
```

## Client Patterns

### Frame Buffering
Most clients maintain a local framebuffer (width × height × 3 bytes for RGB), then send the entire buffer per frame.

```
Client Loop:
1. Clear buffer (or keep for persistence)
2. Set pixels (SetPixel or direct array access)
3. Send() - transmit complete framebuffer
4. Repeat at desired FPS
```

### Layering for Sprites
Use z-offset to render independent layers without knowledge of background:

```
Layer 0: Background image (game world)
Layer 1: Moving character (sprite, black=transparent)
Layer 2: HUD overlay (score, health)
```

Each layer is independent; auto-clears if not updated within timeout.

### Network Discovery
Clients can discover available servers via **PixelPusher Discovery Protocol** (UDP port 7331):

1. Listen on UDP port 7331 for broadcast packets
2. Parse `DiscoveryPacket` to find server IP, MAC, hardware info
3. Connect to discovered server IP on port 1337

(Note: Simple clients often just hardcode `localhost` or accept hostname as argument)

## Configuration & Environment

### Environment Variables
- **`FT_DISPLAY`**: Hostname/IP of server (used by C++ API)
  ```bash
  export FT_DISPLAY=ft.noise  # Use Noisebridge installation
  export FT_DISPLAY=localhost # Use local server
  ```

- **`FT_UDP_SIZE`**: Override UDP packet size (default: 65507)
  ```bash
  export FT_UDP_SIZE=9000  # For OSX (smaller MTU)
  ```

### Common Hostnames
- `localhost` - Local terminal-based server
- `ft.noise` - Noisebridge 45×35 installation
- `ftkleine.noise` - Noisebridge 25×20 display
- `bookcase.noise` - Noisebridge bookshelf LED strips
- `square.noise` - Noisebridge Noise Square Table

## Performance Considerations

### UDP Packet Size Limits
- **Theoretical limit**: 65,535 bytes (UDP max)
- **Practical limit**: ~65,507 bytes (minus IP/UDP headers)
- **OSX limit**: ~9,000 bytes (lower OS MTU)
- **Large displays**: Split across multiple tiles using offsets

**Formula:**
```
packet_size = header_size + (width × height × 3 bytes RGB)
```

For 45×35 display: ~4,800 bytes RGB + ~50 byte header = fits easily

For 160×96 display (LED matrix): 46,080 bytes RGB → requires tiling

### Frame Rate
- No built-in rate limiting
- Network determines actual FPS
- Server layer timeout: 15 seconds (configurable)
- Typical usage: 10-60 FPS per layer

### Network Efficiency
- Send only when changed (animation frames)
- Use layer system to avoid re-sending static content
- Keep images small (scaled to display size)
- Avoid sending at high FPS if network is saturated

## Common Client Types

### Game Clients
- Real-time pixel manipulation (SetPixel)
- Layer support for sprites + background
- Polling for keyboard/input
- Target 30-60 FPS

### Animation/Visualization Clients
- Generate patterns (gradients, waves, particles)
- Update full framebuffer per frame
- May run slower (~10 FPS) for smooth animations

### Data Display Clients
- Render text/numbers to pixel grid
- Update on data change (not real-time)
- Often single-layer

### Overlay/Message Clients
- Send text overlay on layer 1+
- Auto-clears via timeout
- No need for continuous sending
- Good for notifications, scores, alerts

## Testing & Development

### Local Terminal Server
```bash
# Build FT server with terminal backend
cd /Users/brennan/Developer/FT/flaschen-taschen/server
make FT_BACKEND=terminal

# Run
./ft-server -D45x35
```

Then point clients to `localhost:1337`.

### VLC Playback
FT has VLC output plugin for video streaming:
```bash
vlc video.mp4 --loop --vout ft
```

## Debugging Client Issues

**Server not responding?**
- Verify port 1337 is reachable: `nc -u -zv localhost 1337`
- Check firewall rules
- Confirm server is running

**Garbled display?**
- Verify framebuffer size matches server size (-D flag)
- Check PPM header format (P6 magic number, proper newlines)
- Ensure RGB data is correct byte order

**UDP packets fragmented?**
- Reduce framebuffer size
- Use `SetMaxUDPPacketSize()` to split large images
- Use tiling + offsets for large displays

**Performance issues?**
- Reduce frame rate
- Use layer system to avoid full-screen updates
- Profile network bandwidth usage

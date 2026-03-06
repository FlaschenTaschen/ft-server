# Product Requirements Document: FlaschenTaschen Mac Server

## Project Overview

The original Flaschen Taschen (FT) was a 2016 art installation at Noisebridge featuring a wall of 1,575 milk crates with LEDs (45×35 pixel display). This project recreates the FT server as a macOS application, allowing anyone to run a networked LED display simulator on their Mac.

**Goal**: Build a Mac app that simulates a configurable LED display and receives pixel data via UDP network protocol, enabling development, testing, and visualization of FT content.

---

## Architecture

### Core Components

#### 1. Display Server
- Listens on UDP port 1337 for incoming image data
- Receives PPM format images with FT protocol extensions
- Supports configurable display dimensions (default 128×128 pixels)
- Manages image composition with multiple layers (z-offset support)
- Applies x/y offset for image placement
- Updates display in real-time as data arrives

#### 2. Display Renderer (SwiftUI)
- Grid-based visualization matching configured pixel dimensions
- Each pixel rendered as a square (default 16×16 pt)
- Updates pixel colors from network data in real-time
- 1:1 aspect ratio maintained
- Responsive layout that scales with window

#### 3. Settings/Configuration
- Configurable grid dimensions (width × height in pixels)
- Configurable pixel size (width × height in points)
- Network binding address and port configuration
- Layer timeout setting (how long overlay layers persist without updates)
- Display reset/clear controls

---

## Network Protocol

### UDP Protocol Specification
The server implements the **FlaschenTaschen Protocol** (PPM over UDP):

**Port**: 1337 (UDP)
**Format**: PPM binary (`P6`) with FT extensions
**Frame Size**: Single UDP datagram per image (max ~65KB for multi-tile support)

### Packet Structure

```
Header:
  P6              # PPM magic number (binary format)
  width height    # Decimal ASCII numbers (e.g., "128 128")
  #FT: x y z      # Optional FT metadata (offset_x, offset_y, layer)
  255             # Max color value (fixed)

Binary Data:
  [width × height × 3 bytes]  # RGB pixel data (no alpha)

Optional Footer:
  x               # Alternative offset_x (if not in header)
  y               # Alternative offset_y
  z               # Layer/depth value
```

### Protocol Features
- **X/Y Offset**: Position image at any location on display
- **Z-Offset (Layers)**: 0=background, >0=overlay layers
  - Overlays use black (0,0,0) as transparent
  - Auto-disappear after layer timeout (e.g., 15 seconds of inactivity)
- **Backward Compatible**: Ignores extra data at end (valid PPM)

### Example Client Code Pattern
```
jpegtopnm image.jpg | pnmscale -xysize 128 128 | nc -u localhost 1337
```

---

## SwiftUI Interface

### Main Display View
- **Grid Layout**: NxM configurable grid matching display dimensions
- **Pixel Rendering**: Each pixel is a colored square
- **Real-time Updates**: Colors update as UDP packets arrive
- **Visual Feedback**: Display shows received data immediately
- **Scaling**: Window resizable, grid maintains aspect ratio

### Settings View
**Configuration Parameters**:
- Grid Width (default: 128)
- Grid Height (default: 128)
- Pixel Width in points (default: 16)
- Pixel Height in points (default: 16)
- Server Port (default: 1337)
- Bind Address (default: 0.0.0.0 - all interfaces)
- Layer Timeout (seconds, default: 15)

**Controls**:
- Reset/Clear Display button
- Start/Stop Server toggle
- Server Status indicator
- Display Statistics (FPS, packets received, network address)

---

## Technical Requirements

### UDP Server Implementation
- Non-blocking UDP socket listening on configurable port
- PPM parser for binary image data
- FT metadata parser (offset, layer information)
- Image composition engine:
  - Layer management (background + overlay layers)
  - Transparency handling (black = transparent in overlays)
  - Offset application and clipping
- Thread-safe communication between network thread and UI thread

### Data Flow
1. **Network Thread**: Listen for UDP packets → Parse PPM header/data → Validate
2. **Processing**: Apply layer composition, offsets, scaling
3. **UI Thread**: Update display grid with pixel colors (via @Published)
4. **Rendering**: SwiftUI renders updated colors

### SwiftUI State Management
- `@State` for local UI state (settings, window size)
- `@Published` for shared network data (pixel grid, server status)
- ObservableObject for server state management
- Proper lifecycle: start server on app launch, cleanup on exit

### Error Handling
- Invalid PPM format: log and skip packet
- Oversized images: clip to display boundaries
- Network errors: log, maintain server running
- Malformed packets: validate and ignore gracefully

---

## Implementation Phases

### Phase 1: Foundation
- [x] Xcode project setup with minimal headers
- [x] UDP server socket implementation
- [x] PPM parser
- [x] Basic SwiftUI grid display

### Phase 2: Core Functionality
- [x] Real-time pixel updates from network data
- [x] Settings view with configuration options
- [x] Display refresh at appropriate frame rate (30/60/120 FPS configurable)
- [x] Server status display (with FPS counter)

### Phase 3: Advanced Features
- [x] Multi-layer composition with transparency
- [x] X/Y offset support
- [x] Layer timeout management
- [x] Statistics/diagnostics view

### Phase 4: Polish & Testing
- [x] Performance optimization (6 phases complete - see Docs/Performance.md)
- [x] Error handling and logging
- [x] User feedback and status messages
- [ ] Cross-platform testing

---

## Success Criteria

- ✅ Server receives UDP packets on port 1337
- ✅ Parses PPM format images correctly
- ✅ Displays pixel grid matching received dimensions
- ✅ Updates display in real-time (>30 FPS)
- ✅ Supports configurable grid size (100×100 to 200×200+)
- ✅ Handles layer offsets (x, y, z)
- ✅ User can adjust pixel size and grid dimensions via settings
- ✅ Remains responsive during network activity
- ✅ Gracefully handles malformed/oversized packets

---

## Implementation Documentation

The following guides in the `Docs/` folder provide essential guidance for implementation:

- **`Docs/ActorIsolation.md`** - Swift 6 actor patterns and MainActor usage
  - Required reading for understanding actor isolation and thread-safe design
- **`Docs/Logging.md`** - Proper os.log setup and structured logging
  - Guidelines for implementing logging throughout the codebase
- **`Docs/Concurrency.md`** - Async/await patterns and Swift Concurrency best practices
  - Network thread integration and Task-based dispatching to MainActor
- **`Docs/SwiftUI.md`** - SwiftUI best practices and modern API patterns
  - View architecture, state management, and performance optimization

---

## References

- **Original FT Repository**: `/Users/brennan/Developer/FT/flaschen-taschen`
  - Server implementation: `server/` directory (C++)
  - Protocol docs: `doc/protocols.md`
  - Network components: pixel-push-server.cc, ppm-reader
- **VLC Output Module**: Reference implementation showing PPM over UDP
  - Source: `Reference/VLC/flaschen.c`
  - Demonstrates proper UDP packet construction
- **Test Setups**: Original FT server supports terminal and RGB-matrix backends for testing

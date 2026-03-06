# Flaschen Taschen — Swift Implementation

This is a Swift/SwiftUI implementation of the **Flaschen Taschen** networked LED display system, originally created by the Noisebridge community in 2016. Runs on macOS and Apple TV.

## About the Original Project

Flaschen Taschen is an art installation that uses 45×35 pixels (1,575 total) of programmable LEDs arranged in a 9×7 grid of milk crates, each containing clear 12oz bottles wrapped in aluminum foil. The original 2016 installation **won the Editor's Choice Award at Maker Faire**.

The project was inspired by similar installations like MateLight and is a creative reinterpretation of networked LED displays. The original Noisebridge installation featured a Raspberry Pi server that received image data via UDP and displayed it on the physical LED grid.

**Original Project:** https://github.com/hzeller/flaschen-taschen

## This Implementation

A native Swift/SwiftUI app that implements the Flaschen Taschen display as a networked UDP server. The macOS version includes a debugging interface, while the Apple TV version provides a pure display without dev tools.

**Use cases:**

- **Development & Testing** (macOS): Write and test code that targets Flaschen Taschen without access to physical hardware
- **Display Server** (macOS/tvOS): Render the display in real-time on your Mac or Apple TV
- **Multi-Layer Support**: Stack multiple images with transparency and automatic timeout management
- **Network Integration**: Receives standard Flaschen Taschen UDP packets with native platform performance

### Key Features

- **UDP Server**: Listens on port 1337 for incoming image data
- **PPM Format**: Accepts Portable PixMap (PPM) binary format with Flaschen Taschen metadata extensions
- **Multi-Layer Rendering**: Stack multiple images with transparency and automatic cleanup
- **Configurable Display**: Dynamic grid sizing, adjustable frame rates (30/60/120 FPS), and layer timeouts
- **Real-Time Statistics** (macOS): Monitor network activity, frame rates, and active layer counts
- **Native Integration**: Full macOS and tvOS integration for seamless platform experience

### Demo

Live demo of the FT server running on Apple TV:

![Star Wars Demo](StarWars.gif)

## Getting Started

### Requirements

**macOS version:**
- macOS 15+ (Sequoia or later)
- Xcode 16+ (for building from source)

**Apple TV version:**
- tvOS 18+ (for running on Apple TV)

### Building & Running

Open the Xcode project and build/run from Xcode:

```bash
open FlaschenTaschen.xcodeproj
```

Then press **Cmd+R** to run, or select your target (macOS or Apple TV) from the scheme menu.

## Network Protocol

The implementation uses the native Flaschen Taschen UDP protocol:

- **Port**: 1337
- **Format**: PPM binary (P6) with FT metadata extensions
- **Metadata**: `#FT: x y z` for x/y offsets and z-layer

Example packet structure:
```
P6
45 35
255
[FT metadata line]
[binary RGB pixel data]
```

## Configuration (macOS)

Launch the app and press **Cmd+,** to access Settings:

- **Display Presets**: Quick presets for standard resolutions
- **Max Frame Rate**: 30, 60, or 120 FPS
- **Layer Timeout**: Auto-clear overlay layers after N seconds (1–300 sec)
- **Bind Address**: Network interface to listen on

## Architecture

```
UDP Listener (port 1337)
    ↓
PPM Parser (decode binary + FT metadata)
    ↓
Layer Composition (merge layers with transparency)
    ↓
SwiftUI Grid Display (real-time rendering)
```

- **UDPServer**: Network listener using `Network.framework`
- **PPMParser**: Decodes PPM binary format and FT extensions
- **DisplayModel**: Manages layers, composition, and frame rate limiting
- **PixelGridView**: SwiftUI grid component for rendering pixels

## License

MIT License — See LICENSE file for details.

## Credits

- **Original Flaschen Taschen Project**: Created by Noisebridge, 2016
- **Editor's Choice Award**: Maker Faire 2016
- **This Swift Implementation**: macOS simulation and testing environment

## Further Reading

- [Original Project Documentation](https://github.com/hzeller/flaschen-taschen)
- [Flaschen Taschen Wiki](https://noisebridge.net/wiki/Flaschen_Taschen)
- [Network Protocol Specification](https://github.com/hzeller/flaschen-taschen/blob/master/doc/protocols.md)
- [Client Examples](https://github.com/hzeller/flaschen-taschen/tree/master/examples-api-use)

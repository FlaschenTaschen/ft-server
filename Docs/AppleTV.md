# Apple TV Port Analysis: FlaschenTaschen

## Executive Summary

Porting FlaschenTaschen to tvOS is **technically feasible** with moderate effort. The network and composition layers are platform-agnostic, but the UI and input paradigms require significant refactoring for Apple TV's focus-based navigation and remote control interaction.

**Recommendation**: Viable as a Phase 5 project after current macOS release is stable.

---

## Current Architecture (macOS)

### What Works As-Is on tvOS
- **UDPServer**: Pure network layer, no macOS-specific APIs
- **DisplayModel**: Composition engine, layer management (platform-agnostic)
- **PPMParser**: Binary parsing, no platform dependencies
- **PixelColor, LayerStatistics**: Data models (pure Swift)

### What Requires tvOS Adaptation
- **SwiftUI Views**: Focus-based navigation, remote control handling
- **Settings View**: macOS Settings (Cmd+,) doesn't exist on tvOS
- **ServerStatusView**: macOS-specific layout paradigms
- **Input Handling**: No keyboard by default, Siri Remote as primary input

---

## Detailed Analysis

### 1. Network Layer (Minimal Changes Required)

#### Current Implementation
```swift
actor UDPServer {
    private var listener: NWListener
    private var connections: [NWConnection]
    // Uses Network.framework (available on tvOS)
}
```

#### tvOS Compatibility
- ✅ **Network.framework** is available on tvOS 12+
- ✅ **UDP sockets** work identically
- ✅ **Port 1337** can be configured in tvOS entitlements
- ⚠️ **Network privacy**: May require user permission dialog on first connection (tvOS 16+)

#### Required Changes
1. Add tvOS deployment target to Xcode project (tvOS 14+)
2. Possibly request Network Bluetooth permission in Info.plist (if network access check happens)
3. No code changes needed—UDPServer should work unchanged

---

### 2. Display Rendering (Minor Scaling Adjustments)

#### Current Implementation
```swift
PixelGridView: View {
    LazyVGrid(columns: gridColumns, spacing: 0) {
        ForEach(displayModel.pixelData, id: \.id) { pixel in
            PixelView(pixelColor: pixel, size: pixelSize)
        }
    }
}
```

#### tvOS Considerations
- **Screen Size**: 1080p (HD), 4K (preferred)
- **Safe Area**: Larger margins on tvOS (overscan guidelines)
- **Dynamic Scaling**: Current `.aspectFit` logic works, but pixel sizes may differ
- **Focus Handling**: Grid cells need focus rings (visual feedback for remote navigation)

#### Required Changes
1. **Add focus handling**:
   ```swift
   PixelView(pixelColor: pixel, size: pixelSize)
       .focusable() // Enable focus on tvOS
       .focused($focusedPixelId, equals: pixel.id) // Optional: track focus
   ```

2. **Adjust safe area insets** for tvOS overscan (typically 60px margins)

3. **Pixel size calculation**: May need tvOS-specific logic
   - macOS: Dynamic based on window size
   - tvOS: Fixed safe area, different aspect ratio

4. **Remove pointer interaction** (no mouse on tvOS)

5. **Add remote control gestures** (optional—focus navigation sufficient)

---

### 3. Settings Management (Moderate Refactoring)

#### Current Implementation
```swift
// macOS: Settings accessed via Cmd+, or app menu
@State private var showingSettings = false
.focusable() // Keyboard shortcut handling
```

#### tvOS Constraints
- No keyboard by default
- No Cmd+, shortcut
- Settings app pattern doesn't apply to tvOS apps
- Remote control with D-pad + select button for navigation

#### Implementation Strategy

**Option A: Settings Modal (Recommended)**
```swift
ZStack {
    // Main display
    PixelGridView()

    if showSettings {
        // Overlay settings with focus-based navigation
        SettingsModalView()
            .transition(.opacity)
    }
}
.onMoveCommand { direction in
    if direction == .up {
        showSettings = true
    }
}
```

**Option B: Persistent Bottom Panel**
- Display Settings controls at bottom of screen
- Permanently visible, toggle between display/settings focus states
- Similar to current macOS layout but adapted for remote control

**Option C: tvOS Settings (App Info)**
- Use tvOS App Settings (Settings app integration)
- Requires tvOS 14+ settings bundles
- More native but less real-time feedback

#### Required Changes
1. Replace keyboard shortcuts with remote control gestures:
   - `.onMoveCommand { direction in ... }` for D-pad
   - `.onExitCommand { ... }` for back button
   - `.onPlayPauseCommand { ... }` for play/pause (optional)

2. Redesign settings UI for focus navigation
   - TextField inputs → Stepper controls (±buttons)
   - Toggles → Focus-based selection
   - Remove drag/scroll interactions

3. Add visual focus indicators
   - Border/glow around focused control
   - Animated highlight transitions

---

### 4. UI Components (Major Refactoring)

#### ServerStatusView
**Current**: Horizontal row layout with compact metrics
```swift
HStack(spacing: 12) {
    Text("Packets: \(displayModel.packetsReceived)")
    Text("FPS: \(displayModel.currentFPS)")
    // ...
}
```

**tvOS Adaptation**:
- Metrics better displayed as a **vertical sidebar** or **overlay panel** (avoid covering display)
- Larger text for TV viewing distance
- Focus on most important metrics (FPS, layer count)
- Option to hide controls (focus on display)

#### DiagnosticsView
**Current**: Scrollable details list
**tvOS**: Works mostly as-is with:
- Larger fonts for TV viewing
- Focus-based navigation (arrow keys to scroll)
- No horizontal scrolling (focus navigation only)

#### ClosingCircleView
**Current**: Closure indicator circles
**tvOS**: ✅ No changes needed—graphics render identically

---

### 5. Input & Navigation Model

#### Remote Control Mapping

| Siri Remote Control | Function |
|-------------------|----------|
| **D-Pad Up** | Increase selected value / Expand menu |
| **D-Pad Down** | Decrease selected value / Collapse menu |
| **D-Pad Left/Right** | Navigate between settings |
| **Select (center)** | Confirm / Toggle setting |
| **Menu (back)** | Exit settings, return to display |
| **Play/Pause** | Toggle server start/stop (optional) |

#### SwiftUI Implementation
```swift
.onMoveCommand { direction in
    switch direction {
    case .up: selectedSetting -= 1
    case .down: selectedSetting += 1
    case .left: decreaseValue()
    case .right: increaseValue()
    @unknown default: break
    }
}
.onExitCommand {
    showSettings = false
}
```

---

### 7. Service Discovery (Bonjour/mDNS)

For Apple TV to automatically discover Flaschen Taschen servers on the local network, implement Bonjour service discovery.

#### Architecture

**macOS FT Server** registers a Bonjour service
↓
**Apple TV Client** browses and discovers services
↓
**Automatic Connection** to selected server

#### Implementation

##### macOS Server: Register Bonjour Service

In `UDPServer`, register the service when the listener becomes ready:

```swift
actor UDPServer {
    func registerBonjourService() {
        let bonjourService = NWListener.Service(
            name: "Flaschen Taschen",
            type: "_ft._udp",
            domain: "local"
        )

        listener.service = bonjourService
        // Service automatically advertised when listener is active
    }
}
```

Call this when the listener transitions to `.ready` state:

```swift
private func handleStateChange() {
    switch listener.state {
    case .ready:
        registerBonjourService()  // Advertise on network
        // ... existing ready logic
    // ... other cases
    }
}
```

##### Apple TV Client: Browse for Services

Create a service browser:

```swift
@State private var discoveredServers: [NWBrowser.Result] = []
@State private var selectedServer: NWBrowser.Result?

func startBrowsingForServers() {
    let browser = NWBrowser(for: .bonjour(type: "_ft._udp", domain: "local"))

    browser.stateUpdateHandler = { state in
        switch state {
        case .ready, .waiting:
            // Browser is active
            break
        case .failed(let error):
            logger.error("Browser failed: \(error)")
        @unknown default:
            break
        }
    }

    browser.browseResultsChangedHandler = { results, changes in
        DispatchQueue.main.async {
            discoveredServers = Array(results)
        }
    }

    browser.start(queue: .main)
}
```

##### Connect to Discovered Server

```swift
func connectToServer(_ result: NWBrowser.Result) {
    if case .service(let name, let type, let domain, let interface) = result.endpoint {
        let endpoint = NWEndpoint.service(
            name: name,
            type: type,
            domain: domain,
            interface: interface
        )

        // Use endpoint with NWConnection to connect
        let connection = NWConnection(to: endpoint, using: .udp)
        connection.start(queue: .main)
        // ... handle incoming packets
    }
}
```

#### Configuration

##### Info.plist Updates

Add Bonjour service declaration to `Info.plist`:

```xml
<key>NSBonjourServices</key>
<array>
    <string>_ft._udp</string>
</array>

<key>NSLocalNetworkUsageDescription</key>
<string>FlaschenTaschen needs access to your local network to discover and connect to Flaschen Taschen servers.</string>

<key>NSBonjourServiceTypes</key>
<array>
    <string>_ft._udp</string>
</array>
```

##### Network Privacy Entitlements (tvOS)

May require entitlements for local network access on tvOS 16+:

**Entitlements.plist**:
```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.developer.networking.multicast</key>
<true/>
```

#### Service Type Convention

- **Service Name**: `_ft._udp` (Flaschen Taschen over UDP)
- **Readable Name**: "Flaschen Taschen" (shown in UI)
- **Instance Name**: Customizable per server (e.g., "Studio Display", "Gallery Wall")

#### UI: Server Selection View

```swift
struct ServerBrowserView: View {
    @State private var discoveredServers: [NWBrowser.Result] = []
    @State private var selectedServer: NWBrowser.Result?

    var body: some View {
        VStack {
            Text("Available Servers")
                .font(.title)
                .padding()

            List(discoveredServers, id: \.self) { server in
                if case .service(let name, _, _, _) = server.endpoint {
                    Button(action: { selectedServer = server }) {
                        HStack {
                            Text(name)
                            Spacer()
                            if server == selectedServer {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }
            }

            Button("Connect") {
                if let server = selectedServer {
                    connectToServer(server)
                }
            }
            .disabled(selectedServer == nil)
        }
        .onAppear { startBrowsingForServers() }
    }
}
```

#### Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| Services not discovered | Bonjour not registered | Verify `registerBonjourService()` called when listener ready |
| Services disappear | Network change | Browser automatically handles network transitions |
| Connection fails | Wrong service type | Verify `_ft._udp` in both server & client |
| Privacy dialog | First-time network access | User grants permission in tvOS settings |

#### Zero-Configuration Networking

Bonjour enables **zero-configuration networking**:
- ✅ No server IP address needed
- ✅ No manual port configuration
- ✅ Automatic network detection
- ✅ Works across WiFi networks (tvOS) and Ethernet (macOS)
- ✅ Handles network changes automatically

#### Performance Notes

- **Discovery latency**: ~100-500ms after service registration
- **Network overhead**: Minimal (periodic mDNS advertisements)
- **Scalability**: Works with 10+ services on typical local network
- **Reliability**: Automatic fallback to manual IP if discovery fails (optional)

---

### 6. Performance Implications

#### Benefits
- ✅ **Larger display**: LED wall visualization might be more immersive on TV
- ✅ **Dedicated device**: No competing apps, more stable performance
- ✅ **Home automation**: Could be integrated into HomeKit displays

#### Challenges
- ⚠️ **Network latency**: UDP packets over WiFi (tvOS) vs Ethernet (macOS server)
- ⚠️ **Battery**: Not applicable (tvOS devices plugged in)
- ✅ **Rendering**: Same SwiftUI rendering engine, no performance concerns

#### Optimizations Needed
1. May need to adjust UDP buffer sizes (tvOS networking stack may differ)
2. Ensure FPS limiting works correctly with tvOS display refresh rates (60Hz typical)
3. Monitor memory on lower-spec Apple TV models (A10X Fusion on older models)

---

## Implementation Plan

### Phase 5a: tvOS Port Foundation (2-3 days)
1. **Project Setup**
   - Add tvOS 14+ deployment target to Xcode project
   - Create tvOS build scheme
   - Update Info.plist with tvOS requirements

2. **Network Layer Verification**
   - Build UDPServer on tvOS
   - Test UDP connectivity
   - Verify packet reception

3. **Service Discovery (macOS Server)**
   - Register Bonjour service in UDPServer
   - Add `NSBonjourServices` to Info.plist
   - Test service advertisement on local network

4. **Core Display**
   - Port PixelGridView to tvOS
   - Add focus handling
   - Test grid rendering at 1080p and 4K

### Phase 5b: UI Adaptation & Service Discovery (4-5 days)
1. **Service Discovery (tvOS Client)**
   - Implement NWBrowser for service discovery
   - Create ServerBrowserView for selecting servers
   - Handle connection to selected service
   - Add Info.plist privacy declarations

2. **Settings Refactoring**
   - Redesign SettingsModalView for focus-based navigation
   - Implement remote control input handling
   - Add visual focus indicators

3. **Status Display**
   - Adapt ServerStatusView for TV screen layout
   - Optimize font sizes for viewing distance
   - Add toggle to hide/show controls

4. **Input Integration**
   - Implement D-pad navigation
   - Menu button handling
   - Gesture recognition

### Phase 5c: Testing & Polish (2-3 days)
1. **Functional Testing**
   - Test on real Apple TV hardware (4K preferred)
   - Verify UDP reception under various network conditions
   - Test settings changes via remote

2. **UX Polish**
   - Refine focus ring animations
   - Optimize text sizing for 10-12 feet viewing distance
   - Test with actual Siri Remote

3. **Performance Profiling**
   - Monitor CPU/memory during high-frequency UDP packets
   - Test FPS stability on tvOS

---

## Architecture Differences Summary

| Component | macOS | tvOS | Effort |
|-----------|-------|------|--------|
| UDPServer | ✅ Works | ✅ Works unchanged | None |
| DisplayModel | ✅ Works | ✅ Works unchanged | None |
| PixelGridView | ✅ Works | 🔄 Needs focus handling | Low |
| SettingsView | ✅ Works | 🔄 Major UI refactor | High |
| ServerStatusView | ✅ Works | 🔄 Layout adaptation | Medium |
| Input Handling | Keyboard/mouse | Remote control | Medium |
| **Total Effort** | — | — | **Medium (7-10 days)** |

---

## Risk Assessment

### Low Risk
- ✅ Network layer (pure Swift, platform-agnostic)
- ✅ Data models (value types, no platform dependencies)
- ✅ Core display rendering (SwiftUI, identical on tvOS)

### Medium Risk
- ⚠️ Focus navigation (requires testing on real hardware)
- ⚠️ Settings UI (needs careful design for remote control)
- ⚠️ Network performance (WiFi vs Ethernet differences)

### Potential Issues
1. **UDP over WiFi**: tvOS uses WiFi only (no Ethernet option on most models)
   - Mitigation: Ensure robust packet error handling
   - Current code already handles malformed packets

2. **Settings Input**: Remote control limitations
   - Mitigation: Use Stepper controls, drop TextField inputs
   - Affects usability during live adjustment

3. **Hardware Compatibility**: Older Apple TV models (A10X) have limited RAM
   - Mitigation: Current grid (45×35) is tiny; no memory concerns
   - Scales to 128×128 easily on modern hardware

---

## Recommendations

### For Now (macOS Focus)
- ✅ Keep macOS as primary platform
- ✅ Complete Phase 6 optimizations
- ✅ Stabilize and test thoroughly

### For Future (tvOS as Secondary)
1. **Post-release**: Consider tvOS port as Phase 5
2. **Code organization**: Separate view logic from data models (already done via DisplayModel)
3. **Reusability**: Current architecture is highly reusable—minimal changes needed

### Build Strategy
1. **Unified codebase**: Single Xcode project, conditional compilation for platform-specific UI
   ```swift
   #if os(tvOS)
   // tvOS-specific views
   #else
   // macOS-specific views
   #endif
   ```

2. **Shared Core**: Network, composition, data models used unchanged

3. **Platform Views**: Separate view files
   - `ServerStatusView+macOS.swift`
   - `ServerStatusView+tvOS.swift`

---

## Conclusion

**tvOS port is feasible and worthwhile** for:
- Dedicated LED display installations (museum, art exhibitions)
- Home automation integrations
- Large-scale visualization demonstrations

**Effort**: Medium (7-10 days for experienced tvOS developer)
**Risk**: Low to Medium (mostly UI; network layer proven)
**Timeline**: Post-macOS stabilization (Phase 5)

The current macOS implementation provides an excellent foundation for tvOS. The separation of concerns (network/composition vs. UI) makes porting straightforward.

---

## Next Steps

1. **Validate macOS version** is stable and production-ready
2. **Gather requirements** if tvOS deployment is seriously considered
3. **Prototype focus navigation** with sample tvOS app
4. **Schedule tvOS work** after Phase 4 completion (if prioritized)

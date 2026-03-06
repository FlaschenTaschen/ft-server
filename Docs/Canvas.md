# Canvas and Dirty Pixel Optimization: Experiments from Pixels Project

## Status: No Working Optimization Found Yet

Based on investigation of the Pixels project, both Canvas and Dirty Pixel Tracking approaches were attempted but **did not provide the expected performance improvements**. Current state (commit 1a05c62) has regressed to Canvas rendering all pixels.

## Git History of Attempts

| Commit | Changes | Status |
|--------|---------|--------|
| d2234aa | First Canvas implementation | ❌ Failed: "views still update every time pixelData is mutated" |
| 6a61b5f | Canvas + Dirty Pixel Tracking | ❌ Failed: Display issues, reverted |
| 1a05c62 | Regression back to Canvas | Current: Renders all pixels, no dirty tracking |

## The Problem: Real-Time Pixel Updates

Rendering a 45×35 LED grid (1,575 pixels) with SwiftUI when pixels update at 20+ FPS:

- **LazyVGrid approach** (original): Each pixel is an individual Rectangle view. Every Observable mutation invalidates all 1,575 views. Results in 100% CPU load.
- **Canvas approach** (attempted): Single Canvas view reducing view hierarchy overhead, but still iterates all 1,575 pixels per redraw.
- **Canvas + Dirty Pixels** (attempted): Track changed pixels, only redraw those. Theory was sound, but **execution had issues** that caused display problems and forced regression.

## Attempted Solutions (Failed)

### 1. Plain Canvas Rendering

**Attempted in commit d2234aa**

```swift
Canvas { context, size in
    for y in 0..<gridHeight {
        for x in 0..<gridWidth {
            // Draw all 1,575 pixels
        }
    }
}
```

**Problem**: The Observable mutation of `pixelData` still triggers Canvas redraws, which still iterate all pixels. View hierarchy overhead reduced, but observable reactivity still causes frequent full-canvas redraws.

**Result**: Minimal performance improvement. Still high CPU for frequent updates.

### 2. Canvas + Dirty Pixel Tracking

**Attempted in commit 6a61b5f**

```swift
@Observable
final class DisplayModel {
    @ObservationIgnored
    var pixelData: [Point: PixelColor?] = [:]

    @ObservationIgnored
    private var dirtyPixels = Set<Point>()

    var canvasRenderTrigger = 0

    private func updateRandomPixel() {
        pixelData[point] = newColor
        dirtyPixels.insert(point)
        canvasRenderTrigger += 1
    }

    func getDirtyPixels() -> Set<Point> {
        let dirty = dirtyPixels
        dirtyPixels.removeAll()
        return dirty
    }
}
```

Canvas only renders dirty pixels:
```swift
Canvas { context, size in
    _ = displayModel.canvasRenderTrigger
    for point in displayModel.getDirtyPixels() {
        // Only draw changed pixels
    }
}
```

**Expected**: Only 1-2 pixels drawn per update instead of 1,575.

**Actual Result**: ❌ **Display issues**, reverted in 1a05c62. Likely problems:
- Dirty pixels not being tracked correctly
- Canvas partial drawing may not work as expected (clears previous frames?)
- Missing pixels or display corruption
- Thread safety issues with Set mutations from network thread

## Open Questions

What specific issues occurred with the dirty pixel approach?

1. Did pixels disappear/not display?
2. Were updates being lost?
3. Did performance not improve?
4. Was there visual corruption?

Understanding the failure mode is critical for the next approach.

## Alternative Approaches Not Yet Tested

From Proposals.md, other options exist:

- **Metal Rendering** (Option 2): GPU-accelerated, purpose-built for high-performance graphics
- **CADisplayLink + CGContext** (Option 3): Bitmap rendering with native display sync
- **Custom CALayer** (Option 4): Direct graphics control without SwiftUI view system
- **Reduced Update Frequency** (Option 6): Canvas redraw every 100-200ms instead of on every packet

## Next Steps for FlaschenTaschen

1. **Understand the failure**: Document exactly why dirty pixels didn't work in Pixels
2. **Choose approach**: Decide which optimization to implement here
3. **Implement carefully**: With performance testing and visual verification

## References

- Pixels project: `/Users/brennan/Developer/brennanMKE/Pixels`
- Proposals analysis: `Pixels/Docs/Proposals.md` (comprehensive Option 1-6 comparison)

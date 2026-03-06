# Debug Infrastructure

FlaschenTaschen includes a comprehensive debug collection system to capture application state during development. This guide explains how to use the debug script and interpret the collected artifacts.

## Overview

The `debug.sh` script provides a unified interface for building, running, and capturing diagnostic information about the macOS app. Each debug session creates a timestamped folder containing logs, screenshots, and metadata for later review.

## Quick Start

```bash
# Build, run, and capture everything
./debug.sh --note "Testing display grid with 45x35 pixels" build run logs screenshot

# Just capture logs and screenshot from a running app
./debug.sh logs screenshot

# Clean and rebuild
./debug.sh clean build run
```

## Directory Structure

All debug artifacts are stored in the `debug/` directory with the following structure:

```
debug/
├── 20260306-133639/          # Timestamp: YYYYMMDD-HHMMSS
│   ├── metadata.json         # Session metadata and notes
│   ├── logs.txt              # System logs (5-minute window)
│   └── screenshot.png        # Display capture at session time
├── 20260306-145201/
│   ├── metadata.json
│   ├── logs.txt
│   └── screenshot.png
└── ... (more sessions)
```

Each folder is created with a unique timestamp, allowing you to organize and correlate debug artifacts chronologically.

## Usage

### Basic Syntax

```
./debug.sh [--note "description"] <action> [action ...]
```

### Options

- `--note "description"` — Add a descriptive note to the debug session. This is optional but highly recommended for tracking what you were testing.

### Actions (run in sequence)

| Action | Description |
|--------|-------------|
| `build` | Compile the macOS app using Xcode |
| `run` | Launch the built app (requires build to have succeeded) |
| `terminate` | Terminate the running app |
| `logs` | Capture recent system logs (5-minute window) |
| `screenshot` | Capture a screenshot of the app window |
| `send_pirate` | Send pirate.jpg to the running server via UDP and capture screenshot |
| `clean` | Remove build artifacts and derived data |
| `autodebug` | Automated workflow: build → run → wait → logs → screenshot → wait → terminate |

Actions are executed in the order specified on the command line and stop immediately if any action fails.

### Examples

**Quick Automated Testing**

```bash
# Automated workflow: build, run, wait, capture logs/screenshot, terminate
./debug.sh --note "Quick server startup test" autodebug
```

**Manual Development Workflow**

```bash
# Initial build and test with full diagnostics
./debug.sh --note "Initial Phase 1 build" build run logs screenshot

# Test after code changes (faster if build is already clean)
./debug.sh --note "Testing UDP server startup" run logs screenshot

# Full clean rebuild to verify no stale state
./debug.sh --note "Clean rebuild for release testing" clean build run logs screenshot

# Capture diagnostics from running app without rebuilding
./debug.sh --note "Grid rendering with 45x35 pixels" logs screenshot

# Just build without running
./debug.sh build

# Build and run, then collect logs when you're done testing
./debug.sh build run
# (Test the app manually)
./debug.sh logs screenshot

# Build, run for manual testing, then kill when done
./debug.sh build run
# (Manual testing...)
./debug.sh terminate
```

**Testing UDP Image Reception**

```bash
# Build, run, send pirate image, and capture result
./debug.sh --note "Testing pirate image via UDP" build run send_pirate

# Run a clean rebuild and test image reception
./debug.sh --note "Full test: rebuild and pirate image" clean build run send_pirate

# Send image to already-running server (quick test iteration)
./debug.sh --note "Resending pirate image" send_pirate
```

## Artifact Reference

### metadata.json

Contains session metadata for correlation and documentation.

```json
{
  "timestamp": "2026-03-06T13:36:39Z",
  "date_human": "2026-03-06 13:36:39",
  "note": "Testing display grid with 45x35 pixels",
  "app": "FlaschenTaschen",
  "config": "Debug"
}
```

| Field | Purpose |
|-------|---------|
| `timestamp` | ISO 8601 UTC timestamp for server time correlation |
| `date_human` | Human-readable local time for quick reference |
| `note` | Your documentation of what was being tested |
| `app` | Application name (always "FlaschenTaschen") |
| `config` | Build configuration ("Debug" or "Release") |

### logs.txt

System logs captured from the 5 minutes prior to the debug session start. Contains output from both the FlaschenTaschen process and the app's bundle ID (`co.sstools.FlaschenTaschen`).

**Filtering logs after capture:**

```bash
# View all logs from a session
cat debug/20260306-133639/logs.txt

# Search for specific errors
grep -i "error\|fail\|warning" debug/20260306-133639/logs.txt

# Search for UDP server activity
grep -i "udp\|server\|listen" debug/20260306-133639/logs.txt

# Get line count to see activity level
wc -l debug/20260306-133639/logs.txt
```

### screenshot.png

Capture of the FlaschenTaschen app window at the time the debug session was run. If the app window is not found, captures the full screen as a fallback. Useful for verifying visual state of the grid display, UI elements, and any rendering issues.

The screenshot captures just the app window (not the entire display) by searching for the app's bundle ID (`co.sstools.FlaschenTaschen`) in the window list. This produces focused screenshots suitable for comparing builds or tracking rendering changes.

## Development Workflow

### Scenario: Testing UDP Server Auto-Start

The server starts automatically when the app launches. Use debug collection to verify startup:

1. Build and run the app with logging enabled:
   ```bash
   ./debug.sh --note "Testing server auto-start" build run logs screenshot
   ```

2. Review the server startup logs:
   ```bash
   # View all logs from the session
   cat debug/20260306-*/logs.txt

   # Search for server startup messages
   grep -i "udp server\|ready\|port 1337" debug/20260306-*/logs.txt

   # Look for startup errors
   grep -i "error\|failed" debug/20260306-*/logs.txt
   ```

3. Check the app window in the screenshot:
   ```bash
   # Open the screenshot to verify the UI shows "Server: Running"
   open debug/20260306-*/screenshot.png
   ```

**Expected log output:**
```
UDP server starting on port 1337, grid=45x35
UDP server ready, listening on port 1337
```

If you see errors like "Server error:" or "Failed to create listener", the logs will show the issue.

### Scenario: Comparing Two Builds

When testing fixes or optimizations, capture builds before and after:

```bash
# Before fix
./debug.sh --note "Before: UDP parsing fix" build run logs screenshot
# Session saved to debug/20260306-133639/

# Make code changes...

# After fix
./debug.sh --note "After: UDP parsing fix" build run logs screenshot
# Session saved to debug/20260306-145201/

# Compare logs
diff debug/20260306-133639/logs.txt debug/20260306-145201/logs.txt

# Compare screenshots
open debug/20260306-133639/screenshot.png &
open debug/20260306-145201/screenshot.png &
```

### Scenario: Tracking Issues Across Multiple Sessions

```bash
# Collect sessions throughout development
for i in {1..5}; do
  ./debug.sh --note "Test iteration $i" build run logs screenshot
  sleep 2
done

# Examine all metadata to find which session failed
grep -l "error\|Error" debug/*/metadata.json

# View logs from the problematic session
cat debug/20260306-133639/logs.txt

# Check if issue appears in screenshot
open debug/20260306-133639/screenshot.png
```

### Scenario: Testing UDP Image Reception

The `send_pirate` action tests the server's ability to receive and display images via UDP. It sends the pirate.jpg image and captures the result:

1. Build, run, and send the pirate image:
   ```bash
   ./debug.sh --note "Testing pirate image reception" build run send_pirate
   ```

2. Review the screenshot to see the pirate skull displayed in the grid:
   ```bash
   # View the result
   open debug/20260306-*/screenshot.png
   ```

3. Compare with expected result:
   ```bash
   # The screenshot should show:
   # - A 45x35 pixel grid with black background
   # - Pirate skull image centered in the grid
   # - Grid cells rendered as small squares
   ```

4. Test rapid iterations (server already running):
   ```bash
   ./debug.sh --note "Sending pirate image again" send_pirate
   ./debug.sh --note "Another image test" send_pirate
   ```

**What happens:**
1. Runs `send_pirate.sh` which executes `send_pirate.py`
2. `send_pirate.py` loads pirate.jpg, scales to 45x35, and sends via UDP to localhost:1337 in PPM format
3. Waits 3 seconds for the server to process and display
4. Captures screenshot showing the rendered image

## Log Analysis Tips

### Finding Build Issues

```bash
# Check if the build action succeeded
grep -i "build\|failed\|error" debug/20260306-*/logs.txt
```

### Finding Runtime Errors

```bash
# Look for crash logs or exceptions
grep -i "crashed\|exception\|panic" debug/20260306-*/logs.txt
```

### Finding Network Issues

```bash
# Check UDP server startup
grep -i "listen\|udp\|port 1337\|bind" debug/20260306-*/logs.txt
```

### Finding Performance Issues

```bash
# Search for slow operations or timeouts
grep -i "timeout\|slow\|performance" debug/20260306-*/logs.txt
```

## Cleanup

Debug folders accumulate over time. To clean up old sessions:

```bash
# List all debug sessions by age
ls -lht debug/

# Remove debug folders older than 7 days
find debug/ -type d -mtime +7 -exec rm -rf {} \;

# Remove all debug data
rm -rf debug/
```

## Integration with Version Control

The `debug/` directory should not be committed to git. Ensure it's in `.gitignore`:

```
debug/
```

This allows developers to collect local debug artifacts without affecting the repository.

## Autodebug Workflow

The `autodebug` action provides a complete testing cycle in a single command:

```bash
./debug.sh --note "Testing server auto-start" autodebug
```

**What it does:**
1. **Build** - Compiles the app
2. **Run** - Launches the app
3. **Wait** (2 seconds) - Gives server time to start or fail
4. **Send Pirate** - Sends pirate.jpg to the server via UDP and waits 3 seconds
5. **Logs** - Captures system logs to `logs.txt`
6. **Screenshot** - Captures app window to `screenshot.png`
7. **Wait** (3 seconds) - Keeps app running for observation
8. **Terminate** - Kills the app
9. **Complete** - Artifacts saved to timestamped debug folder

**Reviewing results:**
```bash
# After running autodebug, check the latest debug folder
ls -lh debug/*/logs.txt debug/*/screenshot.png | tail -5

# View the screenshot
open debug/20260306-*/screenshot.png

# Check logs
cat debug/20260306-*/logs.txt
```

**Why use autodebug:**
- Single command for complete test cycle
- Consistent timing ensures server has time to start or fail
- Automatic cleanup (app terminates)
- Perfect for CI/CD pipelines or repeated testing
- Quick feedback: build → test → analyze in one go

## Troubleshooting

### Script Not Executable

```bash
chmod +x debug.sh
```

### No Logs Captured

If `logs.txt` is empty, the app may not be running or may not have generated any log output. Check:

1. Did the build succeed? Check for build errors in terminal output
2. Did the app launch? Check `screenshot.png` to see if the window is visible
3. Is the bundle ID correct? (Should be `co.sstools.FlaschenTaschen`)

### Screenshot Not Captured

Verify screencapture is available and working:

```bash
screencapture -x test.png
open test.png
rm test.png
```

### Build Failures

The script stops at the first failing action. Review terminal output for Xcode build errors, then fix and try again:

```bash
./debug.sh clean build
# Fix the build error
./debug.sh build run logs screenshot
```

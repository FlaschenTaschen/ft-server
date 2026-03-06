#!/bin/zsh

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

source config.sh

DEBUG_TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DEBUG_DIR="debug/$DEBUG_TIMESTAMP"
DEBUG_NOTE=""

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

print_step() {
    echo -e "${YELLOW}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

ensure_debug_dir() {
    mkdir -p "$DEBUG_DIR"
}

save_metadata() {
    ensure_debug_dir
    local metadata_file="$DEBUG_DIR/metadata.json"

    cat > "$metadata_file" << EOF
{
  "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')",
  "date_human": "$(date +'%Y-%m-%d %H:%M:%S')",
  "note": "$DEBUG_NOTE",
  "app": "FlaschenTaschen",
  "config": "$CONFIG"
}
EOF

    print_success "Metadata saved: $metadata_file"
}

action_clean() {
    print_header "Cleaning Build Artifacts"
    echo ""

    print_step "Removing derived data..."
    rm -rf "$DERIVED_DATA_PATH"

    print_success "Clean complete"
    echo ""
}

action_build() {
    print_header "Building for macOS"
    echo ""

    local build_log
    build_log=$(mktemp)

    print_step "Building..."
    if ! xcodebuild \
        -scheme "$SCHEME" \
        -configuration "$CONFIG" \
        -derivedDataPath "$DERIVED_DATA_PATH" \
        CODE_SIGN_ENTITLEMENTS="FlaschenTaschen/FlaschenTaschen.entitlements" \
        build > "$build_log" 2>&1; then
        print_error "Build failed"
        tail -50 "$build_log"
        rm -f "$build_log"
        return 1
    fi

    rm -f "$build_log"
    print_success "Build succeeded"
    print_success "App path: $PRODUCT_PATH"
    echo ""
}

action_run() {
    print_header "Launching App"
    echo ""

    if [ ! -d "$PRODUCT_PATH" ]; then
        print_error "Built app not found at: $PRODUCT_PATH"
        print_warning "Run: ./debug.sh build"
        return 1
    fi

    print_step "Launching app..."
    open "$PRODUCT_PATH"

    print_success "App launched"
    echo ""
}

action_terminate() {
    print_header "Terminating App"
    echo ""

    print_step "Terminating FlaschenTaschen..."
    if pkill -f "FlaschenTaschen" 2>/dev/null; then
        print_success "App terminated"
    else
        print_warning "App not running or already terminated"
    fi

    echo ""
}

action_autodebug() {
    print_header "Automated Debug Workflow"
    echo ""

    print_step "Starting automated debug sequence..."
    echo ""

    # Build
    action_build || exit 1

    # Run
    action_run || exit 1

    # Wait for server to start
    print_step "Waiting for server to start (2 seconds)..."
    sleep 2
    echo ""

    # Send pirate image
    action_send_pirate || exit 1

    # Capture logs
    action_logs || exit 1

    # Capture screenshot
    action_screenshot || exit 1

    # Keep running briefly for observation
    print_step "App will terminate in 3 seconds..."
    sleep 3
    echo ""

    # Terminate
    action_terminate || exit 1

    print_success "Automated debug complete - review logs and screenshot"
}

action_logs() {
    print_header "Capturing Logs"
    echo ""

    ensure_debug_dir
    local logs_file="$DEBUG_DIR/logs.txt"

    print_step "Waiting for logs to be written..."
    sleep 2

    print_step "Fetching recent logs from FlaschenTaschen..."
    # Use /usr/bin/log (not the shell built-in)
    # Try using subsystem predicate for os.log output
    /usr/bin/log show --last 5m --predicate "subsystem == \"$BUNDLE_ID\"" 2>/dev/null > "$logs_file"

    # If nothing found, try process predicate
    if [ ! -s "$logs_file" ]; then
        /usr/bin/log show --last 5m --predicate "process == \"FlaschenTaschen\"" 2>/dev/null > "$logs_file"
    fi

    # If still nothing, grep all logs
    if [ ! -s "$logs_file" ]; then
        /usr/bin/log show --last 5m 2>/dev/null | grep -i "flaschen\|udp server\|co.sstools" > "$logs_file" || true
    fi

    local line_count=$(wc -l < "$logs_file")
    if [ "$line_count" -gt 0 ]; then
        print_success "Logs saved: $logs_file ($line_count lines)"
    else
        print_warning "No logs found, created empty file"
    fi

    echo ""
}

action_screenshot() {
    print_header "Capturing Screenshot"
    echo ""

    ensure_debug_dir
    local screenshot_path="$DEBUG_DIR/screenshot.png"

    print_step "Capturing screenshot..."

    local window_id
    window_id=$(windows | grep "$BUNDLE_ID" | awk '{print $1}' | head -1)

    if [ -n "$window_id" ]; then
        screencapture -l "$window_id" "$screenshot_path" 2>/dev/null || true
    else
        print_warning "App window not found, capturing full screen"
        screencapture -x "$screenshot_path" 2>/dev/null || true
    fi

    if [ -f "$screenshot_path" ]; then
        print_success "Screenshot saved: $screenshot_path"
    else
        print_warning "Screenshot capture failed"
    fi

    echo ""
}

action_send_pirate() {
    print_header "Sending Pirate Image"
    echo ""

    if [ ! -f "send_pirate.sh" ]; then
        print_error "send_pirate.sh not found"
        return 1
    fi

    print_step "Running send_pirate.sh..."
    if ! bash send_pirate.sh; then
        print_error "Failed to send pirate image"
        return 1
    fi

    print_step "Waiting for display to update (3 seconds)..."
    sleep 3

    print_success "Image sent, capturing screenshot..."
    action_screenshot || return 1

    echo ""
}

action_help() {
    cat << 'HELP'
Usage: ./debug.sh [--note "description"] <action> [action ...]

Options:
  --note "description"  Add a note describing this debug run

Actions (run in sequence):
  build      Build for macOS
  run        Launch the built app
  terminate  Terminate the running app
  logs       Capture recent logs (5-minute window)
  screenshot Capture a screenshot
  send_pirate Send pirate.jpg to server and capture screenshot
  clean      Clean build artifacts
  autodebug  Automated workflow: build → run → wait → logs → screenshot → terminate

Examples:
  ./debug.sh --note "Quick test" autodebug                    # Automated testing
  ./debug.sh --note "Testing UDP server" build run logs screenshot
  ./debug.sh build run screenshot    # Build, run, and capture
  ./debug.sh build run logs          # Build, run, and show logs
  ./debug.sh logs screenshot         # Just capture logs and screenshot
  ./debug.sh --note "Testing pirate image" build run send_pirate  # Build, run, send image, capture
  ./debug.sh build run terminate     # Build, run, then terminate
  ./debug.sh clean build run         # Clean rebuild and run

Debug Artifacts:
  All artifacts are saved to: debug/YYYYMMDD-HHMMSS/
  - metadata.json   Timestamp and notes
  - logs.txt        Captured system logs
  - screenshot.png  Screenshot of the display

HELP
}

# Parse arguments
ACTIONS=()

while [ $# -gt 0 ]; do
    case "$1" in
        --note)
            shift
            DEBUG_NOTE="$1"
            shift
            ;;
        -h|--help|help)
            action_help
            exit 0
            ;;
        *)
            ACTIONS+=("$1")
            shift
            ;;
    esac
done

if [ ${#ACTIONS[@]} -eq 0 ]; then
    action_help
    exit 0
fi

# Execute actions in sequence
for action in "${ACTIONS[@]}"; do
    case "$action" in
        build)
            action_build || exit 1
            ;;
        run)
            action_run || exit 1
            ;;
        terminate)
            action_terminate || exit 1
            ;;
        logs)
            action_logs || exit 1
            ;;
        screenshot)
            action_screenshot || exit 1
            ;;
        send_pirate)
            action_send_pirate || exit 1
            ;;
        clean)
            action_clean || exit 1
            ;;
        autodebug)
            action_autodebug || exit 1
            ;;
        *)
            print_error "Unknown action: $action"
            echo ""
            action_help
            exit 1
            ;;
    esac
done

# Save metadata at the end
save_metadata

echo -e "${BLUE}✓ All actions completed${NC}"
echo -e "${BLUE}Debug folder: $DEBUG_DIR${NC}"

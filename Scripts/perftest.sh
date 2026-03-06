#!/bin/zsh
# FlaschenTaschen Performance Test Script
# Usage: ./perftest.sh [label]
# Example: ./perftest.sh "baseline" or ./perftest.sh "phase-1-after"

set -e

LABEL="${1:-test-$(date +%s)}"
RESULTS_DIR="debug/performance"
TEST_NAME="perf-${LABEL}-$(date +%Y%m%d-%H%M%S)"
LOG_FILE="${RESULTS_DIR}/${TEST_NAME}.log"
SIGNPOST_FILE="${RESULTS_DIR}/${TEST_NAME}-signposts.log"
METRICS_FILE="${RESULTS_DIR}/${TEST_NAME}-metrics.txt"

# Ensure results directory exists
mkdir -p "$RESULTS_DIR"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║      FlaschenTaschen Performance Test: $LABEL"
echo "║      $(date)"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Find the built app
APP_PATH="/Users/brennan/Library/Developer/Xcode/DerivedData/FlaschenTaschen-hjhuaujgmnjaaqdjpzxwvicsagpr/Build/Products/Debug/FlaschenTaschen.app/Contents/MacOS/FlaschenTaschen"

if [ ! -f "$APP_PATH" ]; then
    echo "❌ ERROR: App not found at $APP_PATH"
    echo "   Please build the app first: xcodebuild build -scheme FlaschenTaschen"
    exit 1
fi

# Kill any existing app instances
echo "→ Cleaning up old app instances..."
pkill -9 -f "FlaschenTaschen.app/Contents/MacOS" 2>/dev/null || true
sleep 2

# Start app fresh
echo "→ Launching FlaschenTaschen app..."
"$APP_PATH" -NSDocumentRevisionsDebugMode YES > /dev/null 2>&1 &
APP_PID=$!
sleep 10

# Verify connection
echo "→ Verifying UDP connectivity to localhost:1337..."
python3 << 'PYEOF'
import socket
try:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.sendto(b'', ('127.0.0.1', 1337))
    sock.close()
    print("  ✓ Server is accepting UDP packets")
except Exception as e:
    print(f"  ✗ Cannot reach server: {e}")
    exit(1)
PYEOF

# Run the animation test
echo "→ Running 40-second animation test..."
echo "  (30s animation + 10s idle collection)"

export FT_DISPLAY=localhost
$HOME/ft/bin/send-image -l5 -t30 Images/mario.gif 2>&1 | grep -v "^$" | sed 's/^/  /'
sleep 10

sleep 5

# Collect logs with extended time window
echo "→ Collecting performance logs..."
/usr/bin/log show --info --last 5m --predicate 'subsystem == "co.sstools.FlaschenTaschen"' > "$LOG_FILE" 2>&1

# Collect signpost timing data
echo "→ Collecting signpost timing data..."
/usr/bin/log show --info --signpost --last 5m --predicate 'subsystem == "co.sstools.FlaschenTaschen"' > "$SIGNPOST_FILE" 2>&1

# Extract metrics
echo "→ Extracting performance metrics..."
{
    echo "Performance Test Results"
    echo "========================"
    echo "Test Label: $LABEL"
    echo "Test Time: $(date)"
    echo "Duration: 40 seconds (30s active + 10s idle)"
    echo ""

    # Extract all FPS measurements
    FPS_LINES=$(grep "Performance: FPS=" "$LOG_FILE" 2>/dev/null)
    FPS_COUNT=$(echo "$FPS_LINES" | wc -l | tr -d ' ')

    echo "Data Collection:"
    echo "  FPS measurements: $FPS_COUNT"
    echo ""

    if [ "$FPS_COUNT" -gt 0 ]; then
        echo "FPS Measurements (all $FPS_COUNT):"
        echo "$FPS_LINES" | sed -n 's/.*\[.*DisplayModel\] \(Performance:.*\)/  \1/p'
        echo ""

        # Extract FPS values
        FPS_VALUES=$(echo "$FPS_LINES" | sed -n 's/.*FPS=\([0-9]*\).*/\1/p')
        PACKET_VALUES=$(echo "$FPS_LINES" | sed -n 's/.*Packets=\([0-9]*\).*/\1/p')

        if [ -n "$FPS_VALUES" ]; then
            AVG_FPS=$(echo "$FPS_VALUES" | awk '{sum+=$1; count++} END {if (count>0) printf "%.1f", sum/count}')
            MAX_FPS=$(echo "$FPS_VALUES" | sort -rn | head -1)
            MIN_FPS=$(echo "$FPS_VALUES" | sort -n | head -1)
            echo "FPS Statistics:"
            echo "  Average: $AVG_FPS"
            echo "  Max: $MAX_FPS"
            echo "  Min: $MIN_FPS"
            echo ""
        fi

        if [ -n "$PACKET_VALUES" ]; then
            TOTAL_PACKETS=$(echo "$PACKET_VALUES" | tail -1)
            echo "Packet Statistics:"
            echo "  Total Packets: $TOTAL_PACKETS"
            echo "  Avg Rate: $(echo "scale=1; $TOTAL_PACKETS / 30" | bc) packets/sec"
            echo ""
        fi
    fi

    # Extract signpost timing data using parse_signposts.py
    echo "Signpost Timing Statistics:"

    if [ -f "parse_signposts.py" ] && [ -f "$SIGNPOST_FILE" ]; then
        # Run the Python parser and capture output
        PARSER_OUTPUT=$(python3 parse_signposts.py "$SIGNPOST_FILE" 2>&1)

        if [ $? -eq 0 ]; then
            # Extract just the timing table (Operation header through data rows)
            echo "$PARSER_OUTPUT" | awk '
                /^Operation/ {flag=1}
                flag && /^-+$/ {count++; if (count==2) flag=0}
                flag {print}
            ' | sed 's/^/  /'

            echo ""
            echo "  For detailed per-file breakdown, run:"
            echo "    python3 parse_signposts.py debug/performance/perf-${LABEL}*.log"
        else
            echo "  Error running parse_signposts.py - falling back to event counts"
            SIGNPOST_LINES=$(grep "Signpost" "$SIGNPOST_FILE" 2>/dev/null | grep -E "applyLayerUpdate|composePixelData|updateLayerStats|fpsMeasurement" || true)
            SIGNPOST_COUNT=$(echo "$SIGNPOST_LINES" | wc -l | tr -d ' ')
            if [ "$SIGNPOST_COUNT" -gt 0 ]; then
                echo "    Total events: $SIGNPOST_COUNT"
            fi
        fi
    else
        if [ ! -f "parse_signposts.py" ]; then
            echo "  ⚠ parse_signposts.py not found - install it from project root"
        else
            echo "  (No signpost data captured)"
        fi
    fi

    echo ""
    echo "Log files:"
    echo "  Metrics: $METRICS_FILE"
    echo "  Raw logs: $LOG_FILE"
    echo "  Signposts: $SIGNPOST_FILE"
} | tee "$METRICS_FILE"

echo ""
echo "✓ Performance test complete!"
echo "  Results: $METRICS_FILE"
echo "  Raw logs: $LOG_FILE"
echo "  Signposts: $SIGNPOST_FILE"

# Kill the app
kill $APP_PID 2>/dev/null || true

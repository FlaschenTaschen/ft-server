#!/bin/zsh

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Display presets matching SettingsView.swift
declare -A PRESETS=(
    ["original"]="45 35"
    ["small"]="32 24"
    ["medium"]="45 35"
    ["large"]="64 48"
    ["very-large"]="128 22"
)

# Check for text argument
if [[ $# -lt 1 ]]; then
    echo "${RED}Error: Text required${NC}"
    echo "Usage: $0 <text> [-p <preset>|<width> <height>] [options]"
    echo ""
    echo "Presets:"
    for preset in "${(@k)PRESETS}"; do
        dims=(${=PRESETS[$preset]})
        echo "  -p $preset      ${dims[1]}×${dims[2]}"
    done
    echo ""
    echo "Options:"
    echo "  -x <offset>    X offset (default: 0)"
    echo "  -y <offset>    Y offset (default: 0)"
    echo "  -z <layer>     Z layer (default: 1)"
    echo "  -s <size>      Font size (default: 8)"
    echo "  -c <RRGGBB>    Text color as hex (default: FFFFFF)"
    echo "  -b <RRGGBB>    Background color as hex (default: 000000)"
    exit 1
fi

echo "${YELLOW}Checking requirements for send_text.py${NC}"

# Check Python3
if ! command -v python3 &> /dev/null; then
    echo "${RED}✗ python3 is required but not installed${NC}"
    exit 1
fi
echo "${GREEN}✓ python3 found${NC}"

# Check PIL/pillow
if ! python3 -c "import PIL" 2>/dev/null; then
    echo "${RED}✗ pillow module is required${NC}"
    echo "  Install with: pip install pillow"
    exit 1
fi
echo "${GREEN}✓ pillow found${NC}"

echo ""

# Default dimensions
WIDTH=45
HEIGHT=35

TEXT="$1"
shift

# Parse preset or dimensions
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "-p" && $# -gt 1 ]]; then
        PRESET="$2"
        if [[ -n "${PRESETS[$PRESET]}" ]]; then
            dims=(${=PRESETS[$PRESET]})
            WIDTH=${dims[1]}
            HEIGHT=${dims[2]}
            echo "${GREEN}✓ Using preset '$PRESET' (${WIDTH}×${HEIGHT})${NC}"
            shift 2
        else
            echo "${RED}✗ Unknown preset: $PRESET${NC}"
            exit 1
        fi
    elif [[ "$1" =~ ^[0-9]+$ && $# -gt 1 && "$2" =~ ^[0-9]+$ ]]; then
        WIDTH="$1"
        HEIGHT="$2"
        echo "${GREEN}✓ Using custom dimensions (${WIDTH}×${HEIGHT})${NC}"
        shift 2
    fi
fi

echo "${GREEN}All requirements satisfied. Running send_text.py...${NC}"
echo ""

python3 send_text.py "$TEXT" "$WIDTH" "$HEIGHT" "$@"

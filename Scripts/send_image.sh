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

# Check for image path argument
if [[ $# -lt 1 ]]; then
    echo "${RED}Error: Image path required${NC}"
    echo "Usage: $0 <image_path> [-p <preset>|<width> <height>]"
    echo ""
    echo "Presets:"
    for preset in "${(@k)PRESETS}"; do
        dims=(${=PRESETS[$preset]})
        echo "  -p $preset      ${dims[1]}×${dims[2]}"
    done
    exit 1
fi

IMAGE_PATH="$1"
shift

echo "${YELLOW}Checking requirements for send_image.py${NC}"

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

# Check image file exists
if [[ ! -f "$IMAGE_PATH" ]]; then
    echo "${RED}✗ Image file not found: $IMAGE_PATH${NC}"
    exit 1
fi
echo "${GREEN}✓ $IMAGE_PATH found${NC}"

echo ""

# Default dimensions
WIDTH=45
HEIGHT=35

# Parse preset or dimensions
if [[ $# -gt 0 ]]; then
    if [[ "$1" == "-p" && $# -gt 1 ]]; then
        PRESET="$2"
        if [[ -n "${PRESETS[$PRESET]}" ]]; then
            dims=(${=PRESETS[$PRESET]})
            WIDTH=${dims[1]}
            HEIGHT=${dims[2]}
            echo "${GREEN}✓ Using preset '$PRESET' (${WIDTH}×${HEIGHT})${NC}"
        else
            echo "${RED}✗ Unknown preset: $PRESET${NC}"
            exit 1
        fi
    elif [[ "$1" =~ ^[0-9]+$ && $# -gt 1 && "$2" =~ ^[0-9]+$ ]]; then
        WIDTH="$1"
        HEIGHT="$2"
        echo "${GREEN}✓ Using custom dimensions (${WIDTH}×${HEIGHT})${NC}"
    fi
fi

echo "${GREEN}All requirements satisfied. Running send_image.py...${NC}"
echo ""

python3 send_image.py "$IMAGE_PATH" "$WIDTH" "$HEIGHT"

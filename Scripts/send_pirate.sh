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

PRESET="${1:-original}"

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
if [[ ! -f "Images/pirate.jpg" ]]; then
    echo "${RED}✗ Images/pirate.jpg not found${NC}"
    exit 1
fi
echo "${GREEN}✓ Images/pirate.jpg found${NC}"

echo ""

# Get dimensions from preset
if [[ -n "${PRESETS[$PRESET]}" ]]; then
    dims=(${=PRESETS[$PRESET]})
    WIDTH=${dims[1]}
    HEIGHT=${dims[2]}
    echo "${GREEN}✓ Using preset '$PRESET' (${WIDTH}×${HEIGHT})${NC}"
else
    echo "${RED}✗ Unknown preset: $PRESET${NC}"
    echo "Available presets:"
    for p in "${(@k)PRESETS}"; do
        echo "  $p"
    done
    exit 1
fi

echo "${GREEN}All requirements satisfied. Running send_image.py...${NC}"
echo ""

python3 send_image.py Images/pirate.jpg "$WIDTH" "$HEIGHT"

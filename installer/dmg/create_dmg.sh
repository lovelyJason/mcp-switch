#!/bin/bash
#
# Create a beautiful DMG installer for MCP Switch
# Usage: ./create_dmg.sh [version]
#
# Prerequisites:
#   - brew install create-dmg
#   - Flutter macOS app must be built first: flutter build macos --release
#

set -e

# Configuration
APP_NAME="MCP Switch"
BUNDLE_NAME="MCP Switch"
VERSION="${1:-1.0.2}"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
BUILD_DIR="$PROJECT_ROOT/build/macos/Build/Products/Release"
APP_PATH="$BUILD_DIR/$BUNDLE_NAME.app"
OUTPUT_DIR="$PROJECT_ROOT/build/dmg"
DMG_NAME="${APP_NAME// /-}-${VERSION}.dmg"
BACKGROUND_IMG="$SCRIPT_DIR/background.png"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Creating DMG for $APP_NAME v$VERSION   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v create-dmg &> /dev/null; then
    echo -e "${RED}Error: create-dmg not found. Install with: brew install create-dmg${NC}"
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo -e "${RED}Error: App not found at $APP_PATH${NC}"
    echo -e "${YELLOW}Please build the app first: flutter build macos --release${NC}"
    exit 1
fi

if [ ! -f "$BACKGROUND_IMG" ]; then
    echo -e "${YELLOW}Background image not found. Generating...${NC}"
    cd "$SCRIPT_DIR"
    python3 create_background.py
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Remove existing DMG if it exists
if [ -f "$OUTPUT_DIR/$DMG_NAME" ]; then
    echo -e "${YELLOW}Removing existing DMG...${NC}"
    rm "$OUTPUT_DIR/$DMG_NAME"
fi

# Create DMG
echo -e "${YELLOW}Creating DMG...${NC}"
echo ""

create-dmg \
    --volname "$APP_NAME" \
    --background "$BACKGROUND_IMG" \
    --window-pos 200 120 \
    --window-size 540 380 \
    --icon-size 100 \
    --icon "$BUNDLE_NAME.app" 135 190 \
    --hide-extension "$BUNDLE_NAME.app" \
    --app-drop-link 405 190 \
    --no-internet-enable \
    "$OUTPUT_DIR/$DMG_NAME" \
    "$APP_PATH"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          DMG Created Successfully!     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Output: ${GREEN}$OUTPUT_DIR/$DMG_NAME${NC}"
echo ""

# Show file info
ls -lh "$OUTPUT_DIR/$DMG_NAME"

# Optional: Open the DMG to verify
read -p "Open DMG to verify? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "$OUTPUT_DIR/$DMG_NAME"
fi

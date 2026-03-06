#!/usr/bin/env python3
"""Send text to FT server on localhost via UDP PPM format."""

import socket
import sys
from PIL import Image, ImageDraw, ImageFont

# Configuration
HOST = 'localhost'
PORT = 1337
DISPLAY_WIDTH = 45
DISPLAY_HEIGHT = 35
MAX_UDP_SIZE = 65507  # Theoretical maximum (65535 - 20 byte IP - 8 byte UDP header)

# Text rendering defaults
DEFAULT_FONT_SIZE = 8
DEFAULT_COLOR = (255, 255, 255)
DEFAULT_BG_COLOR = (0, 0, 0)

def create_text_image(text, width, height, font_size=DEFAULT_FONT_SIZE,
                     color=DEFAULT_COLOR, bg_color=DEFAULT_BG_COLOR):
    """Render text onto an image."""
    img = Image.new('RGB', (width, height), bg_color)
    draw = ImageDraw.Draw(img)

    try:
        # Try to use a system font
        font = ImageFont.truetype("/System/Library/Fonts/Monaco.dfont", font_size)
    except (OSError, IOError):
        # Fallback to default font
        font = ImageFont.load_default()

    # Get text bounding box to center it
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    # Center the text
    x = max(0, (width - text_width) // 2)
    y = max(0, (height - text_height) // 2)

    draw.text((x, y), text, fill=color, font=font)
    return img

def send_text(text, x_offset=0, y_offset=0, z_offset=1,
              width=DISPLAY_WIDTH, height=DISPLAY_HEIGHT,
              font_size=DEFAULT_FONT_SIZE,
              color=DEFAULT_COLOR, bg_color=DEFAULT_BG_COLOR):
    """Send text to FT server."""

    # Check if server is reachable
    sock_check = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock_check.settimeout(1)
    try:
        sock_check.sendto(b'', (HOST, PORT))
    except (socket.gaierror, socket.error, OSError) as e:
        print(f"Error: Cannot reach server at {HOST}:{PORT} - {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        sock_check.close()

    # Create text image
    img = create_text_image(text, width, height, font_size, color, bg_color)

    # Build PPM packet
    packet = f'P6\n{width} {height}\n#FT: {x_offset} {y_offset} {z_offset}\n255\n'.encode('ascii')

    # Add RGB pixel data
    for y in range(height):
        for x in range(width):
            r, g, b = img.getpixel((x, y))
            packet += bytes([r, g, b])

    # Send via UDP
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Try to increase socket buffer on macOS
        try:
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65507)
        except OSError:
            pass  # If it fails, continue with default buffer

        sock.sendto(packet, (HOST, PORT))
        print(f"✓ Sent text '{text}' to {HOST}:{PORT}")
    except (socket.gaierror, socket.error, OSError) as e:
        packet_size = len(packet)
        if "Message too long" in str(e):
            print(f"Error: Packet size {packet_size} bytes exceeds OS limit", file=sys.stderr)
            print(f"Try a smaller preset or dimensions", file=sys.stderr)
            # Calculate what would fit
            max_bytes = 9000
            max_height = max(1, (max_bytes - 100) // (width * 3))
            print(f"Recommended max height for {width}px width: {max_height} pixels", file=sys.stderr)
        else:
            print(f"Error: Failed to send packet - {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        sock.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <text> [width] [height] [options]", file=sys.stderr)
        print("Options:", file=sys.stderr)
        print("  -x <offset>    X offset (default: 0)", file=sys.stderr)
        print("  -y <offset>    Y offset (default: 0)", file=sys.stderr)
        print("  -z <layer>     Z layer (default: 1)", file=sys.stderr)
        print("  -s <size>      Font size (default: 8)", file=sys.stderr)
        print("  -c <RRGGBB>    Text color as hex (default: FFFFFF)", file=sys.stderr)
        print("  -b <RRGGBB>    Background color as hex (default: 000000)", file=sys.stderr)
        sys.exit(1)

    text = sys.argv[1]
    width = int(sys.argv[2]) if len(sys.argv) > 2 and sys.argv[2].isdigit() else DISPLAY_WIDTH
    height = int(sys.argv[3]) if len(sys.argv) > 3 and sys.argv[3].isdigit() else DISPLAY_HEIGHT
    x_offset = 0
    y_offset = 0
    z_offset = 1
    font_size = DEFAULT_FONT_SIZE
    color = DEFAULT_COLOR
    bg_color = DEFAULT_BG_COLOR

    # Parse options
    i = 4
    while i < len(sys.argv):
        if sys.argv[i] == '-x' and i + 1 < len(sys.argv):
            x_offset = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == '-y' and i + 1 < len(sys.argv):
            y_offset = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == '-z' and i + 1 < len(sys.argv):
            z_offset = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == '-s' and i + 1 < len(sys.argv):
            font_size = int(sys.argv[i + 1])
            i += 2
        elif sys.argv[i] == '-c' and i + 1 < len(sys.argv):
            hex_color = sys.argv[i + 1]
            r = int(hex_color[0:2], 16)
            g = int(hex_color[2:4], 16)
            b = int(hex_color[4:6], 16)
            color = (r, g, b)
            i += 2
        elif sys.argv[i] == '-b' and i + 1 < len(sys.argv):
            hex_color = sys.argv[i + 1]
            r = int(hex_color[0:2], 16)
            g = int(hex_color[2:4], 16)
            b = int(hex_color[4:6], 16)
            bg_color = (r, g, b)
            i += 2
        else:
            i += 1

    send_text(text, x_offset, y_offset, z_offset, font_size=font_size,
              color=color, bg_color=bg_color)

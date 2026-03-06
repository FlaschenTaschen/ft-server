#!/usr/bin/env python3
"""Send image to FT server on localhost via UDP PPM format."""

import socket
import sys
from PIL import Image

# Configuration
HOST = 'localhost'
PORT = 1337
DEFAULT_WIDTH = 45
DEFAULT_HEIGHT = 35
MAX_UDP_SIZE = 65507  # Theoretical maximum (65535 - 20 byte IP - 8 byte UDP header)

# Get image path from command line argument
if len(sys.argv) < 2:
    print(f"Usage: {sys.argv[0]} <image_path> [width] [height]", file=sys.stderr)
    sys.exit(1)

IMAGE_PATH = sys.argv[1]
WIDTH = int(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_WIDTH
HEIGHT = int(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_HEIGHT

# Check if server is reachable
sock_check = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
sock_check.settimeout(1)
try:
    # UDP doesn't connect, but we can test with a tiny ping
    sock_check.sendto(b'', (HOST, PORT))
except (socket.gaierror, socket.error, OSError) as e:
    print(f"Error: Cannot reach server at {HOST}:{PORT} - {e}", file=sys.stderr)
    sys.exit(1)
finally:
    sock_check.close()

# Load and scale image
try:
    img = Image.open(IMAGE_PATH).convert('RGB')
    img = img.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
except FileNotFoundError:
    print(f"Error: Image file not found: {IMAGE_PATH}", file=sys.stderr)
    sys.exit(1)

# Build PPM packet
packet = f'P6\n{WIDTH} {HEIGHT}\n255\n'.encode('ascii')

# Add RGB pixel data
for y in range(HEIGHT):
    for x in range(WIDTH):
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
    print(f"✓ Sent {IMAGE_PATH} ({WIDTH}×{HEIGHT}) to {HOST}:{PORT}")
except (socket.gaierror, socket.error, OSError) as e:
    packet_size = len(packet)
    if "Message too long" in str(e):
        print(f"Error: Packet size {packet_size} bytes exceeds OS limit", file=sys.stderr)
        print(f"Try a smaller preset or dimensions", file=sys.stderr)
        # Calculate what would fit
        max_bytes = 9000
        max_height = max(1, (max_bytes - 100) // (WIDTH * 3))
        print(f"Recommended max height for {WIDTH}px width: {max_height} pixels", file=sys.stderr)
    else:
        print(f"Error: Failed to send packet - {e}", file=sys.stderr)
    sys.exit(1)
finally:
    sock.close()

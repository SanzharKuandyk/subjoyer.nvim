#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Verbose test - prints ALL messages with type labels
"""

import asyncio
import websockets
import json
import sys
import io
from datetime import datetime

# Force UTF-8 encoding for Windows
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

async def handle_client(websocket):
    """Handle incoming WebSocket connection"""
    client_addr = websocket.remote_address
    print(f"\n{'='*60}")
    print(f"✓ Extension connected from {client_addr[0]}:{client_addr[1]}")
    print(f"{'='*60}\n")

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                msg_type = data.get('type', 'unknown')

                # Print message type prominently
                print(f"\n>>> MESSAGE TYPE: {msg_type}")

                if msg_type == 'connected':
                    version = data.get('version', 'unknown')
                    print(f"    Extension version: {version}")
                    print(f"    Timestamp: {data.get('timestamp')}")

                elif msg_type == 'heartbeat':
                    print(f"    Heartbeat at: {data.get('timestamp')}")

                elif msg_type == 'subtitle':
                    subtitle = data.get('subtitle', {})
                    video = data.get('video', {})
                    lines = subtitle.get('lines', [])

                    print(f"    ✨ SUBTITLE RECEIVED!")
                    print(f"    Video time: {video.get('currentTime', 0):.2f}s")
                    print(f"    Number of lines: {len(lines)}")

                    for line in lines:
                        track = line.get('track', 0)
                        text = line.get('text', '')
                        print(f"    Track {track}: {text}")

                    # Also print full subtitle text if available
                    if subtitle.get('text'):
                        print(f"    Full text: {subtitle.get('text')}")

                else:
                    print(f"    Unknown type, full data:")
                    print(f"    {json.dumps(data, indent=2)}")

                # Always print raw JSON for debugging
                print(f"    RAW JSON: {json.dumps(data, ensure_ascii=False)}")
                print()

            except json.JSONDecodeError as e:
                print(f"⚠ Invalid JSON: {e}")

    except websockets.exceptions.ConnectionClosed:
        print(f"\n{'='*60}")
        print(f"✗ Extension disconnected from {client_addr[0]}:{client_addr[1]}")
        print(f"{'='*60}\n")

async def main():
    """Start WebSocket server"""
    host = "localhost"
    port = 8766

    print(f"\n{'='*60}")
    print(f"  Verbose WebSocket Test Server")
    print(f"{'='*60}\n")
    print(f"🚀 Starting on ws://{host}:{port}")
    print(f"\n{'─'*60}")
    print("Steps:")
    print("  1. Make sure asbplayer-streamer extension is configured:")
    print("     - Transport: WebSocket")
    print("     - URL: ws://localhost:8766")
    print("  2. Open a video (YouTube, Netflix, etc.)")
    print("  3. Load subtitles in asbplayer")
    print("  4. Play the video")
    print(f"{'─'*60}\n")

    server = await websockets.serve(
        handle_client,
        host,
        port,
        ping_interval=None
    )

    print("✓ Server ready, waiting for connection...\n")
    await server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n👋 Server stopped")
    except Exception as e:
        print(f"\n❌ Error: {e}")
        raise

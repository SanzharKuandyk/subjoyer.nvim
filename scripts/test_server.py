#!/usr/bin/env python3
"""
Test the WebSocket server independently.
This helps debug connection issues before testing with Neovim.

Requirements: pip install websockets

Usage:
    python test_server.py

Then configure asbplayer-streamer extension to connect to ws://localhost:8767
"""

import asyncio
import websockets
import json

async def handle_client(websocket):
    """Handle incoming WebSocket connection"""
    print("✓ Client connected!")

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                msg_type = data.get('type', 'unknown')

                if msg_type == 'subtitle':
                    subtitle = data.get('subtitle', {})
                    video = data.get('video', {})

                    # Print subtitle info
                    current_time = video.get('currentTime', 0)
                    minutes = int(current_time // 60)
                    seconds = int(current_time % 60)

                    print(f"\n[{minutes:02d}:{seconds:02d}] Subtitle received:")

                    # Print lines if available
                    lines = subtitle.get('lines', [])
                    if lines:
                        for line in lines:
                            track = line.get('track', 0)
                            text = line.get('text', '')
                            print(f"  Track {track}: {text}")
                    else:
                        # Fallback to text field
                        text = subtitle.get('text', '')
                        print(f"  {text}")

                elif msg_type == 'connected':
                    version = data.get('version', 'unknown')
                    print(f"✓ Extension connected (version: {version})")

                elif msg_type == 'heartbeat':
                    print("💓 Heartbeat")

                elif msg_type == 'disconnected':
                    print("✗ Extension disconnected")

                else:
                    print(f"? Unknown message type: {msg_type}")

            except json.JSONDecodeError as e:
                print(f"⚠ JSON decode error: {e}")

    except websockets.exceptions.ConnectionClosed:
        print("✗ Client disconnected")

async def main():
    """Start WebSocket server"""
    host = 'localhost'
    port = 8767

    print("=" * 60)
    print("  subjoyer.nvim - WebSocket Server Test")
    print("=" * 60)
    print(f"\n🚀 Starting server on ws://{host}:{port}")
    print("\nNext steps:")
    print("  1. Configure asbplayer-streamer extension:")
    print("     - Set transport to 'WebSocket'")
    print("     - Set URL to 'ws://localhost:8767'")
    print("  2. Play a video with asbplayer")
    print("  3. Watch subtitles appear here!")
    print("\n" + "=" * 60)
    print("Waiting for connections...\n")

    server = await websockets.serve(handle_client, host, port, ping_interval=None)

    await server.wait_closed()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n\n👋 Server stopped (Ctrl+C)")
    except Exception as e:
        print(f"\n❌ Error: {e}")

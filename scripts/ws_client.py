#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
subjoyer.nvim - WebSocket Server
Receives subtitle messages from asbplayer-streamer extension and outputs to stdout.

Requirements:
    pip install websockets

Usage:
    python ws_client.py [--host HOST] [--port PORT]
"""

import asyncio
import websockets
import json
import sys
import argparse
import io
from typing import Optional

# Force UTF-8 encoding for stdout/stderr to handle Unicode subtitles (Japanese, etc.)
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')


class SubtitleWebSocketServer:
    def __init__(self, host: str = 'localhost', port: int = 8766):
        self.host = host
        self.port = port
        self.server: Optional[websockets.WebSocketServer] = None

    async def handle_client(self, websocket):
        """Handle incoming WebSocket connection"""
        # Log connection (to stderr so it doesn't interfere with JSON output)
        client_addr = websocket.remote_address
        print(f"[DEBUG] Extension connected from {client_addr[0]}:{client_addr[1]}", file=sys.stderr, flush=True)

        try:
            async for message in websocket:
                try:
                    # Parse and validate JSON
                    data = json.loads(message)

                    # Output to stdout for neovim to read
                    # Use compact JSON format (single line)
                    output = json.dumps(data, ensure_ascii=False)
                    print(output, flush=True)

                except json.JSONDecodeError as e:
                    # Log error to stderr (visible in neovim debug)
                    print(f"ERROR: Invalid JSON: {e}", file=sys.stderr, flush=True)

        except websockets.exceptions.ConnectionClosed:
            # Connection closed, output disconnect event
            print(f"[DEBUG] Extension disconnected from {client_addr[0]}:{client_addr[1]}", file=sys.stderr, flush=True)
            disconnect_event = {
                "type": "client_disconnected",
                "timestamp": 0
            }
            print(json.dumps(disconnect_event), flush=True)

        except Exception as e:
            # Unexpected error
            print(f"ERROR: {e}", file=sys.stderr, flush=True)

    async def start(self):
        """Start WebSocket server"""
        try:
            self.server = await websockets.serve(
                self.handle_client,
                self.host,
                self.port,
                ping_interval=None  # Extension sends heartbeats
            )

            # Output ready event to stdout
            ready_event = {
                "type": "server_ready",
                "host": self.host,
                "port": self.port
            }
            print(json.dumps(ready_event), flush=True)

            # Keep server running
            await self.server.wait_closed()

        except OSError as e:
            # Port already in use or other OS error
            error_event = {
                "type": "server_error",
                "error": str(e)
            }
            print(json.dumps(error_event), flush=True)
            sys.exit(1)

        except Exception as e:
            error_event = {
                "type": "server_error",
                "error": str(e)
            }
            print(json.dumps(error_event), flush=True)
            sys.exit(1)

    async def stop(self):
        """Stop WebSocket server"""
        if self.server:
            self.server.close()
            await self.server.wait_closed()


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='WebSocket server for subjoyer.nvim')
    parser.add_argument('--host', default='localhost', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8766, help='Port to bind to')
    args = parser.parse_args()

    server = SubtitleWebSocketServer(host=args.host, port=args.port)

    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        # Clean shutdown on Ctrl+C
        shutdown_event = {
            "type": "server_shutdown",
            "reason": "keyboard_interrupt"
        }
        print(json.dumps(shutdown_event), flush=True)
        sys.exit(0)


if __name__ == "__main__":
    main()

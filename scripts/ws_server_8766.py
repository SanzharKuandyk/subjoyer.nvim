#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
subjoyer.nvim - asbplayer WebSocket Server
Accepts connections from asbplayer WebSocket client and forwards commands from Neovim.

Requirements:
    pip install websockets

Usage:
    python ws_server_8766.py [--host HOST] [--port PORT]
"""

import asyncio
import websockets.asyncio.server
import json
import sys
import argparse
import io
from typing import Optional
import threading

# Force UTF-8 encoding for stdout/stderr
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')


class AsbplayerWebSocketServer:
    def __init__(self, host: str = '127.0.0.1', port: int = 8766):
        self.host = host
        self.port = port
        self.server = None
        self.client_websocket = None
        self.command_queue = asyncio.Queue()

    async def handle_client(self, websocket):
        """Handle incoming WebSocket connection from asbplayer"""
        print(f"[DEBUG] Connection from {websocket.remote_address}", file=sys.stderr, flush=True)

        # Only allow one client at a time
        if self.client_websocket:
            print(f"[DEBUG] Client already connected, rejecting", file=sys.stderr, flush=True)
            return

        self.client_websocket = websocket
        client_addr = websocket.remote_address
        print(f"[DEBUG] asbplayer connected from {client_addr[0]}:{client_addr[1]}", file=sys.stderr, flush=True)

        # Notify Neovim of connection
        connection_event = {
            "type": "asbplayer_connected",
            "client": f"{client_addr[0]}:{client_addr[1]}"
        }
        print(json.dumps(connection_event), flush=True)

        send_task = None
        try:
            # Start send task in background
            send_task = asyncio.create_task(self.process_command_queue(websocket))

            # Main receive loop
            await self.receive_messages(websocket)

        except Exception as e:
            print(f"[DEBUG] Client handler error: {e}", file=sys.stderr, flush=True)
        finally:
            # Cancel send task if still running
            if send_task:
                send_task.cancel()
                try:
                    await send_task
                except asyncio.CancelledError:
                    pass

            self.client_websocket = None
            disconnect_event = {
                "type": "asbplayer_disconnected",
                "client": f"{client_addr[0]}:{client_addr[1]}"
            }
            print(json.dumps(disconnect_event), flush=True)

    async def receive_messages(self, websocket):
        """Receive messages from asbplayer client"""
        try:
            async for message in websocket:
                try:
                    # Handle text messages
                    if isinstance(message, str):
                        # asbplayer uses text-based PING/PONG for keepalive
                        if message.strip() == "PING":
                            print(f"[DEBUG] Received PING, sending PONG", file=sys.stderr, flush=True)
                            await websocket.send("PONG")
                            continue

                        # Parse JSON response
                        data = json.loads(message)

                        # Forward response to Neovim
                        output = {
                            "type": "asbplayer_response",
                            "data": data
                        }
                        print(json.dumps(output, ensure_ascii=False), flush=True)

                except json.JSONDecodeError as e:
                    print(f"[DEBUG] Invalid JSON: {message!r}", file=sys.stderr, flush=True)
                except Exception as e:
                    print(f"[DEBUG] Error processing message: {e}", file=sys.stderr, flush=True)
        except websockets.exceptions.ConnectionClosed:
            pass  # Normal disconnection

    async def process_command_queue(self, websocket):
        """Process commands from Neovim and send to asbplayer"""
        print(f"[DEBUG] Command queue processor started", file=sys.stderr, flush=True)
        try:
            while True:
                try:
                    # Wait for command from queue
                    command = await asyncio.wait_for(
                        self.command_queue.get(),
                        timeout=1.0
                    )

                    print(f"[DEBUG] Dequeued command: {command.get('command')}", file=sys.stderr, flush=True)
                    # Send command to asbplayer client
                    command_json = json.dumps(command)
                    print(f"[DEBUG] Sending to asbplayer: {command_json}", file=sys.stderr, flush=True)
                    await websocket.send(command_json)
                    print(f"[DEBUG] Sent successfully", file=sys.stderr, flush=True)

                except asyncio.TimeoutError:
                    # No command, continue waiting
                    continue
                except Exception as e:
                    print(f"[DEBUG] Error sending command: {e}", file=sys.stderr, flush=True)
                    import traceback
                    traceback.print_exc(file=sys.stderr)
                    break
        except asyncio.CancelledError:
            print(f"[DEBUG] Command queue processor cancelled", file=sys.stderr, flush=True)
            raise

    async def stdin_reader(self):
        """Read commands from stdin (Neovim) and queue them"""
        loop = asyncio.get_running_loop()

        def read_stdin():
            """Blocking stdin read in thread"""
            print(f"[DEBUG] Stdin reader thread started", file=sys.stderr, flush=True)
            while True:
                try:
                    line = sys.stdin.readline()
                    if not line:
                        print(f"[DEBUG] Stdin EOF", file=sys.stderr, flush=True)
                        break
                    line = line.strip()
                    if line:
                        print(f"[DEBUG] Stdin received: {line}", file=sys.stderr, flush=True)
                        try:
                            command = json.loads(line)
                            print(f"[DEBUG] Queueing command: {command.get('command')}", file=sys.stderr, flush=True)
                            # Queue command for sending to client
                            asyncio.run_coroutine_threadsafe(
                                self.command_queue.put(command),
                                loop
                            )
                        except json.JSONDecodeError as e:
                            print(f"[DEBUG] Invalid JSON from stdin: {e}", file=sys.stderr, flush=True)
                except Exception as e:
                    print(f"[DEBUG] Error reading stdin: {e}", file=sys.stderr, flush=True)
                    import traceback
                    traceback.print_exc(file=sys.stderr)
                    break

        # Run stdin reader in thread to avoid blocking
        thread = threading.Thread(target=read_stdin, daemon=True)
        thread.start()
        print(f"[DEBUG] Stdin reader thread launched", file=sys.stderr, flush=True)

    async def start(self):
        """Start WebSocket server"""
        try:
            # Start stdin reader
            await self.stdin_reader()

            # Output ready event to stdout
            ready_event = {
                "type": "asbplayer_server_ready",
                "url": f"ws://{self.host}:{self.port}/ws"
            }
            print(json.dumps(ready_event), flush=True)

            # Start WebSocket server (websockets 16.0 API)
            async with websockets.asyncio.server.serve(self.handle_client, self.host, self.port):
                await asyncio.Future()  # run forever

        except OSError as e:
            # Port already in use or other OS error
            error_event = {
                "type": "asbplayer_server_error",
                "error": str(e)
            }
            print(json.dumps(error_event), flush=True)
            sys.exit(1)

        except Exception as e:
            error_event = {
                "type": "asbplayer_server_error",
                "error": str(e)
            }
            print(json.dumps(error_event), flush=True)
            sys.exit(1)


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(description='asbplayer WebSocket server for subjoyer.nvim')
    parser.add_argument('--host', default='127.0.0.1', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8766, help='Port to bind to')
    args = parser.parse_args()

    server = AsbplayerWebSocketServer(host=args.host, port=args.port)

    try:
        asyncio.run(server.start())
    except KeyboardInterrupt:
        # Clean shutdown on Ctrl+C
        shutdown_event = {
            "type": "asbplayer_server_shutdown",
            "reason": "keyboard_interrupt"
        }
        print(json.dumps(shutdown_event), flush=True)
        sys.exit(0)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Minimal WebSocket server to test ping/pong.
Usage: python test_ping_pong.py
Then connect asbplayer to ws://127.0.0.1:8766/ws
"""

import asyncio
import websockets.asyncio.server

async def handler(websocket):
    print(f"Client connected from {websocket.remote_address}")
    try:
        async for message in websocket:
            print(f"Received: {message!r}")
            # Handle PING with PONG (asbplayer uses text-based ping/pong)
            if message.strip() == "PING":
                print("  -> Sending PONG")
                await websocket.send("PONG")
            else:
                # Echo other messages
                await websocket.send(f"Echo: {message}")
    except websockets.exceptions.ConnectionClosed:
        print("Client disconnected")

async def main():
    print("Starting minimal server on ws://127.0.0.1:8766")
    print("Ping/pong should be automatic...")

    async with websockets.asyncio.server.serve(handler, "127.0.0.1", 8766):
        await asyncio.Future()  # run forever

if __name__ == "__main__":
    asyncio.run(main())

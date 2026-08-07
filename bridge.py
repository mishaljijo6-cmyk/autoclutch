"""
Bridge Server — Receives steering commands from the browser via WebSocket
and presses real system-wide keyboard keys.

Usage:
    pip install websockets pydirectinput
    python bridge.py

Then open the hosted HTML page — it auto-connects to ws://localhost:8765
"""

import asyncio
import json
import signal
import sys
import ctypes
import os

try:
    import websockets
except ImportError:
    print("ERROR: 'websockets' package not found.")
    print("Install it:  pip install websockets")
    sys.exit(1)

try:
    from pynput.keyboard import Controller, KeyCode
except ImportError:
    print("ERROR: 'pynput' package not found.")
    print("Install it:  pip install pynput")
    sys.exit(1)

# ── Configuration ──────────────────────────────────────────────────
HOST = "localhost"
PORT = 8765
STEER_KEYS = (KeyCode.from_char('a'), KeyCode.from_char('d'))
# ───────────────────────────────────────────────────────────────────

keyboard = Controller()
current_key = None
connected_clients = set()


def press_key(key):
    global current_key
    if current_key == key:
        return
    release_key()
    keyboard.press(key)
    current_key = key
    print(f"  [Bridge] Steering: {key}")


def release_key():
    global current_key
    if current_key is not None:
        keyboard.release(current_key)
        print("  [Bridge] Steering: CENTER (Released)")
        current_key = None


async def handle_client(websocket):
    """Handle a single browser client connection."""
    global current_key
    addr = websocket.remote_address
    connected_clients.add(websocket)
    print(f"  ✓ Browser connected from {addr[0]}:{addr[1]}")

    try:
        async for message in websocket:
            try:
                data = json.loads(message)
                cmd = data.get("cmd", "")

                if cmd == "left":
                    press_key(STEER_KEYS[0])
                elif cmd == "right":
                    press_key(STEER_KEYS[1])
                elif cmd == "release":
                    release_key()
                elif cmd == "ping":
                    await websocket.send(json.dumps({"status": "ok"}))

            except json.JSONDecodeError:
                pass

    except websockets.exceptions.ConnectionClosed:
        pass
    finally:
        release_key()
        connected_clients.discard(websocket)
        print(f"  ✗ Browser disconnected from {addr[0]}:{addr[1]}")


async def main():
    print("=" * 55)
    print("  HEAD-TILT STEERING  —  Bridge Server")
    print("=" * 55)
    print(f"  WebSocket:  ws://{HOST}:{PORT}")
    print(f"  Keys:       Left={STEER_KEYS[0]}, Right={STEER_KEYS[1]}")
    print("-" * 55)
    print("  Waiting for browser to connect...")
    print("  (Open the hosted HTML page in your browser)")
    print("-" * 55)
    print("  ⚠️ IMPORTANT FOR GAMES ⚠️")
    print("  1. If your game expects A and D to steer, this now presses them too!")
    print("  2. If it STILL doesn't work, you MUST run this script as Administrator.")
    print("     (Some games block keyboard inputs from non-admin scripts)")
    print("-" * 55)
    print("  Press Ctrl+C to stop\n")

    stop = asyncio.get_event_loop().create_future()

    # Handle Ctrl+C gracefully
    def _signal_handler():
        if not stop.done():
            stop.set_result(None)

    try:
        loop = asyncio.get_event_loop()
        loop.add_signal_handler(signal.SIGINT, _signal_handler)
    except NotImplementedError:
        # Windows doesn't support add_signal_handler
        pass

    async with websockets.serve(handle_client, HOST, PORT):
        try:
            await asyncio.Future()  # Run forever
        except asyncio.CancelledError:
            pass

    release_key()
    print("\nBridge stopped.")

def is_admin():
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

if __name__ == "__main__":
    if not is_admin():
        print("Requesting Administrator privileges (required for some games)...")
        # Re-run the program with admin rights. Use __file__ in quotes to handle spaces in path.
        script_path = os.path.abspath(__file__)
        ctypes.windll.shell32.ShellExecuteW(None, "runas", sys.executable, f'"{script_path}"', None, 1)
        sys.exit()
        
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        release_key()
        print("\nBridge stopped.")

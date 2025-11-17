#!/bin/bash
echo "[SWILL] Installing server on Termux..."
pkg update && pkg upgrade -y
pkg install -y python python-pip vnc-viewer
pip install -r requirements.txt
echo "[SWILL] Installation complete!"
echo "[SWILL] Run: python swill_server.py"
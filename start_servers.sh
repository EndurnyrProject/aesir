#!/bin/bash

echo "Starting Aesir Ragnarok Online Server..."

# Start Account Server
echo "Starting Account Server..."
RELEASE_COOKIE=imthecookie iex --name account@127.0.0.1 -S mix aesir.account &
ACCOUNT_PID=$!

# Wait a moment before starting the next server
sleep 2

# Start Char Server
echo "Starting Char Server..."
RELEASE_COOKIE=imthecookie iex --name char@127.0.0.1 -S mix aesir.char &
CHAR_PID=$!

# Wait a moment before starting the next server
sleep 2

# Start Zone Server
echo "Starting Zone Server..."
RELEASE_COOKIE=imthecookie iex --name zone@127.0.0.1 -S mix aesir.zone &
ZONE_PID=$!

echo "All servers started!"
echo "Account Server PID: $ACCOUNT_PID"
echo "Char Server PID: $CHAR_PID"
echo "Zone Server PID: $ZONE_PID"

# Function to kill all servers
cleanup() {
	echo "Shutting down servers..."
	kill -9 $ACCOUNT_PID $CHAR_PID $ZONE_PID 2>/dev/null
	exit 0
}

# Trap Ctrl+C and call cleanup
trap cleanup SIGINT

# Wait for all background processes
wait

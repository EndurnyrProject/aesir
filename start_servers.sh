#!/bin/bash
set -euo pipefail

# Starts the Aesir account, char and zone servers, each in its own interactive
# iex shell. Prefers zellij, then tmux, so every server gets a live pane you can
# attach to. Falls back to plain background jobs when neither is available.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SESSION="aesir"
COOKIE="imthecookie"

ACCOUNT_CMD="RELEASE_COOKIE=$COOKIE iex --name account@127.0.0.1 -S mix aesir.account"
CHAR_CMD="RELEASE_COOKIE=$COOKIE iex --name char@127.0.0.1 -S mix aesir.char"
ZONE_CMD="RELEASE_COOKIE=$COOKIE iex --name zone@127.0.0.1 -S mix aesir.zone"

# Char and zone wait briefly so the account server boots and clusters first.
CHAR_CMD_STAGGERED="sleep 2; $CHAR_CMD"
ZONE_CMD_STAGGERED="sleep 4; $ZONE_CMD"

start_zellij() {
	if zellij list-sessions -ns 2>/dev/null | grep -qx "$SESSION"; then
		echo "Zellij session '$SESSION' already exists; attaching."
		exec zellij attach --force-run-commands "$SESSION"
	fi

	echo "Creating zellij session '$SESSION'..."
	# Clear any stale/exited session so the name is free for a fresh layout.
	zellij delete-session "$SESSION" >/dev/null 2>&1 || true

	local layout_dir layout
	layout_dir="$(mktemp -d "${TMPDIR:-/tmp}/aesir.XXXXXX")"
	layout="$layout_dir/layout.kdl"

	cat >"$layout" <<-EOF
		layout {
		    pane split_direction="vertical" {
		        pane name="account" cwd="$SCRIPT_DIR" {
		            command "bash"
		            args "-c" "$ACCOUNT_CMD"
		        }
		        pane name="char" cwd="$SCRIPT_DIR" {
		            command "bash"
		            args "-c" "$CHAR_CMD_STAGGERED"
		        }
		        pane name="zone" cwd="$SCRIPT_DIR" {
		            command "bash"
		            args "-c" "$ZONE_CMD_STAGGERED"
		        }
		    }
		}
	EOF

	zellij --session "$SESSION" --new-session-with-layout "$layout"
	rm -rf "$layout_dir"
}

start_tmux() {
	echo "Starting Aesir servers in tmux session '$SESSION'..."

	if tmux has-session -t "$SESSION" 2>/dev/null; then
		echo "Session '$SESSION' already exists; attaching."
		attach_tmux
		return
	fi

	tmux new-session -d -s "$SESSION" -n servers -c "$SCRIPT_DIR" "$ACCOUNT_CMD"
	tmux split-window -t "$SESSION" -c "$SCRIPT_DIR" "$CHAR_CMD_STAGGERED"
	tmux split-window -t "$SESSION" -c "$SCRIPT_DIR" "$ZONE_CMD_STAGGERED"
	tmux select-layout -t "$SESSION" tiled
	attach_tmux
}

attach_tmux() {
	if [ -n "${TMUX:-}" ]; then
		tmux switch-client -t "$SESSION"
	else
		tmux attach-session -t "$SESSION"
	fi
}

start_plain() {
	echo "Neither zellij nor tmux found; starting servers as background jobs."
	cd "$SCRIPT_DIR"

	echo "Starting Account Server..."
	eval "$ACCOUNT_CMD" &
	local account_pid=$!
	sleep 2

	echo "Starting Char Server..."
	eval "$CHAR_CMD" &
	local char_pid=$!
	sleep 2

	echo "Starting Zone Server..."
	eval "$ZONE_CMD" &
	local zone_pid=$!

	echo "All servers started!"
	echo "Account Server PID: $account_pid"
	echo "Char Server PID: $char_pid"
	echo "Zone Server PID: $zone_pid"

	cleanup() {
		echo "Shutting down servers..."
		kill -9 "$account_pid" "$char_pid" "$zone_pid" 2>/dev/null
		exit 0
	}
	trap cleanup SIGINT

	wait
}

if command -v zellij >/dev/null 2>&1; then
	start_zellij
elif command -v tmux >/dev/null 2>&1; then
	start_tmux
else
	start_plain
fi

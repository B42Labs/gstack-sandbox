#!/usr/bin/env bash
set -e

# Ensure /workspace is owned by claude if mounted as root
if [ -d /workspace ] && [ "$(stat -c '%u' /workspace 2>/dev/null)" = "0" ]; then
    sudo chown -R claude:claude /workspace 2>/dev/null || true
fi

# Configure git safe directory for mounted repos
git config --global --add safe.directory /workspace

# Install gstack skills into the workspace project if not already present
if [ -d /workspace ] && [ ! -d /workspace/.claude/skills/gstack ]; then
    mkdir -p /workspace/.claude/skills
    ln -sf /home/claude/.claude/skills/gstack /workspace/.claude/skills/gstack
    echo "[gstack] Linked skills into /workspace/.claude/skills/gstack"
fi

# Start tmux session
exec tmux new-session -s dev -c /workspace

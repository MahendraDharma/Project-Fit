#!/bin/bash
# Installs REA (Reverse Engineer Anything) and Ghidra for Claude Code cloud sessions.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

REA_VERSION="6.5.0"
GHIDRA_VERSION="12.1.4"
GHIDRA_BUILD="20260921"
GHIDRA_SHA256="ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db"
GHIDRA_DIR="/opt/ghidra_${GHIDRA_VERSION}_PUBLIC"
# GitHub release downloads are blocked in cloud sessions, so use the SourceForge
# mirror and verify against the hash published on the official GitHub release.
GHIDRA_URL="https://downloads.sourceforge.net/project/ghidra.mirror/Ghidra_${GHIDRA_VERSION}_build/ghidra_${GHIDRA_VERSION}_PUBLIC_${GHIDRA_BUILD}.zip"

# Ghidra needs a JDK 21+.
if ! command -v javac >/dev/null 2>&1; then
  apt-get update -qq && apt-get install -y -qq openjdk-21-jdk-headless >/dev/null
fi

if [ ! -x "$GHIDRA_DIR/support/analyzeHeadless" ]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  curl -fsSL --retry 3 -o "$tmp/ghidra.zip" "$GHIDRA_URL"
  echo "$GHIDRA_SHA256  $tmp/ghidra.zip" | sha256sum -c --quiet -
  unzip -q "$tmp/ghidra.zip" -d /opt
fi

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export GHIDRA_INSTALL_DIR=\"$GHIDRA_DIR\"" >> "$CLAUDE_ENV_FILE"
fi

# Install the REA skill into ~/.claude/skills; the MCP server itself is
# registered in the project's .mcp.json. Run outside the repo so npx never
# resolves a local package.
cd /tmp
npx -y "rea-agents@${REA_VERSION}" setup --skill-client claude_code --yes >/dev/null

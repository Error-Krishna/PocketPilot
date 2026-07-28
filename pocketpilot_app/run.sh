#!/usr/bin/env bash
# Runs the PocketPilot Flutter app, auto-detecting this Mac's current
# local network IP so the API_URL always points at the right place —
# no more hardcoding or manually editing api_service.dart.
#
# Also auto-accepts Android SDK licenses on first run so builds don't
# fail on a fresh setup (no Android Studio required, just the SDK
# command-line tools via `brew install --cask android-commandlinetools`).
#
# Usage:
#   ./run.sh                 # auto-detect IP, flutter run
#   ./run.sh -d <device_id>  # target a specific device
#   ./run.sh build apk       # any other flutter subcommand + args

set -euo pipefail

# --- Auto-accept Android SDK licenses (idempotent, safe to run every time) ---
if command -v sdkmanager >/dev/null 2>&1; then
  yes | sdkmanager --licenses >/dev/null 2>&1 || true
elif [ -n "${ANDROID_HOME:-}" ] && [ -x "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" ]; then
  yes | "${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager" --licenses >/dev/null 2>&1 || true
else
  echo "Warning: sdkmanager not found on PATH or under \$ANDROID_HOME."
  echo "If the build fails with a license error, install the SDK command-line"
  echo "tools first:  brew install --cask android-commandlinetools"
  echo ""
fi

# --- Detect this Mac's current local network IP ---
IP=""
for iface in en0 en1 en2; do
  IP=$(ipconfig getifaddr "$iface" 2>/dev/null || true)
  if [ -n "$IP" ]; then
    break
  fi
done

if [ -z "$IP" ]; then
  echo "Could not auto-detect local IP (tried en0/en1/en2)."
  echo "Find it manually with: ifconfig | grep 'inet '"
  exit 1
fi

PORT="${BACKEND_PORT:-8000}"
API_URL="http://${IP}:${PORT}/api/v1"

echo "Detected local IP: ${IP}"
echo "Using API_URL:     ${API_URL}"
echo ""

SUBCOMMAND="${1:-run}"
shift || true

flutter "$SUBCOMMAND" --dart-define=API_URL="$API_URL" "$@"

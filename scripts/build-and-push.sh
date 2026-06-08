#!/usr/bin/env bash
set -euo pipefail

# ───────────────────────────────────────────────────────
# Build and push the dummy-app Docker image
#
# Usage: ./scripts/build-and-push.sh <image-tag>
#
# This script builds the dummy-app Go binary locally and
# uses it as user_data on EC2. No registry needed.
#
# For the EC2-based setup, the app runs via a Python HTTP
# server provisioned through user_data. This script is
# included for reference if you want to use the Go binary.
# ───────────────────────────────────────────────────────

TAG="${1:-latest}"

echo "Building dummy-app..."

cd "$(dirname "$0")/../dummy-app"

GOOS=linux GOARCH=amd64 go build -o app main.go

echo "Binary built: $(pwd)/app"
echo ""
echo "The app is now deployed automatically via EC2 user_data."
echo "To build a Docker image instead:"
echo "  docker build -t dr-sim-dummy:$TAG ."

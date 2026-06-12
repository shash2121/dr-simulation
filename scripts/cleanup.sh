#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# DR Simulation - Full Cleanup
#
# Destroys all infrastructure in both regions.
# Run from the dr-simulation directory.
#
# Usage: ./scripts/cleanup.sh
# ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

PRIMARY_TFVARS="primary-us-east-1.tfvars"
DR_TFVARS="dr-us-east-2.tfvars"

echo "========================================"
echo "  Destroying DR Simulation Infra"
echo "========================================"

# ─────────────────────────────────────────────────────────
# Step 1: Destroy Primary Region
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 1: Destroy primary region (us-east-1) ==="

terraform workspace select default 2>/dev/null || terraform workspace new default
terraform init -reconfigure

echo "Destroying primary infra..."
terraform destroy \
  -var-file="$PRIMARY_TFVARS" \
  -auto-approve

echo "Primary region destroyed."

# ─────────────────────────────────────────────────────────
# Step 2: Destroy DR Region
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 2: Destroy DR region (us-east-2) ==="

terraform workspace select dr 2>/dev/null || terraform workspace new dr
terraform init -reconfigure

echo "Destroying DR infra..."
terraform destroy \
  -var-file="$DR_TFVARS" \
  -auto-approve

echo "DR region destroyed."

# ─────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────
echo ""
echo "========================================"
echo "  Cleanup Complete!"
echo "========================================"

#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Simulate a failure by blocking ingress to the primary ALB
#
# Usage: ./scripts/simulate-failure.sh <primary-region> <alb-sg-id>
#
# Effects:
#   1. Revokes HTTP ingress from the primary ALB security group
#   2. Route 53 health check → UNHEALTHY
#   3. DNS failover routes traffic to the DR region
# ─────────────────────────────────────────────────────────

PRIMARY_REGION="${1:?Usage: $0 <primary-region> <alb-sg-id>}"
ALB_SG_ID="${2:?Usage: $0 <primary-region> <alb-sg-id>}"

echo "=== Simulating failure in $PRIMARY_REGION ==="
echo "Revoking HTTP ingress from ALB SG: $ALB_SG_ID"

aws ec2 revoke-security-group-ingress \
  --region "$PRIMARY_REGION" \
  --group-id "$ALB_SG_ID" \
  --protocol tcp \
  --port 80 \
  --cidr "0.0.0.0/0" 2>/dev/null || true

echo "=== Failure injected ==="
echo "Primary ALB is now unreachable."
echo "Route 53 health check will fail within ~90 seconds."
echo "Traffic will automatically shift to DR region if DNS failover is configured."

#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Failover: Promote DR region to become the new primary
#
# Usage: ./scripts/failover.sh <dr-region> <replica-db-instance-identifier>
#
# Steps:
#   1. Promote the cross-region RDS read replica to standalone
#   2. Scale up EKS nodes in DR (if scaled down)
#   3. Show new DR endpoint
# ─────────────────────────────────────────────────────────

DR_REGION="${1:?Usage: $0 <dr-region> <replica-db-instance-identifier>}"
REPLICA_ID="${2:?Usage: $0 <dr-region> <replica-db-instance-identifier>}"

echo "=== Step 1: Promoting RDS read replica ==="
echo "Promoting $REPLICA_ID in $DR_REGION to standalone..."
aws rds promote-read-replica \
  --region "$DR_REGION" \
  --db-instance-identifier "$REPLICA_ID"

echo "Waiting for promotion to complete..."
aws rds wait db-instance-available \
  --region "$DR_REGION" \
  --db-instance-identifier "$REPLICA_ID"
echo "RDS promotion complete."

echo "=== Step 2: Get new endpoint ==="
NEW_ENDPOINT=$(aws rds describe-db-instances \
  --region "$DR_REGION" \
  --db-instance-identifier "$REPLICA_ID" \
  --query 'DBInstances[0].Endpoint.Address' --output text)

echo ""
echo "=== Failover complete ==="
echo "DR RDS is now standalone and accepting writes."
echo "RDS Endpoint: $NEW_ENDPOINT"
echo ""
echo "Next steps:"
echo "1. Update Secrets Manager with new RDS endpoint in DR region"
echo "2. Restart EKS pods if needed to pick up new credentials"
echo "3. Verify app is healthy on DR ALB endpoint"

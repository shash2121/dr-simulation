#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# Failback: Restore primary region as the active site
#
# Usage: ./scripts/failback.sh <primary-region> <dr-region> \
#         <primary-db-id> <dr-db-id>
#
# Steps:
#   1. Restore primary ALB SG ingress (re-enable HTTP)
#   2. Create snapshot of the promoted DR RDS
#   3. Copy snapshot to primary region
#   4. Restore primary RDS from the snapshot
# ─────────────────────────────────────────────────────────

PRIMARY_REGION="${1:?Usage: $0 <primary-region> <dr-region> <primary-db-id> <dr-db-id>}"
DR_REGION="${2:?}"
PRIMARY_DB_ID="${3:?}"
DR_DB_ID="${4:?}"

echo "=== Step 1: Restoring primary ALB access ==="
echo "Re-add HTTP ingress to the primary ALB security group:"
echo "  cd primary-region && terraform output alb_alb_security_group_id"
echo "  aws ec2 authorize-security-group-ingress \\"
echo "    --region $PRIMARY_REGION \\"
echo "    --group-id <sg-id> \\"
echo "    --protocol tcp --port 80 --cidr 0.0.0.0/0"
echo ""

echo "=== Step 2: Creating snapshot of DR RDS ==="
SNAPSHOT_ID="${DR_DB_ID}-pre-failback-$(date +%s)"
aws rds create-db-snapshot \
  --region "$DR_REGION" \
  --db-instance-identifier "$DR_DB_ID" \
  --db-snapshot-identifier "$SNAPSHOT_ID"

aws rds wait db-snapshot-complete \
  --region "$DR_REGION" \
  --db-instance-identifier "$DR_DB_ID" \
  --db-snapshot-identifier "$SNAPSHOT_ID"
echo "Snapshot $SNAPSHOT_ID created."

echo "=== Step 3: Copy snapshot to primary region ==="
SNAPSHOT_ARN=$(aws rds describe-db-snapshots \
  --region "$DR_REGION" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --query 'DBSnapshots[0].DBSnapshotArn' --output text)

aws rds copy-db-snapshot \
  --region "$PRIMARY_REGION" \
  --source-db-snapshot-identifier "$SNAPSHOT_ARN" \
  --target-db-snapshot-identifier "${SNAPSHOT_ID}-copied"

aws rds wait db-snapshot-complete \
  --region "$PRIMARY_REGION" \
  --db-snapshot-identifier "${SNAPSHOT_ID}-copied"
echo "Snapshot copied to $PRIMARY_REGION."

echo ""
echo "=== Manual steps remaining ==="
echo "1. Restore primary RDS from snapshot:"
echo "   aws rds restore-db-instance-from-db-snapshot \\"
echo "     --region $PRIMARY_REGION \\"
echo "     --db-instance-identifier $PRIMARY_DB_ID \\"
echo "     --db-snapshot-identifier ${SNAPSHOT_ID}-copied"
echo ""
echo "2. Create a new read replica in DR region pointing to the restored primary"
echo "3. Update Secrets Manager with primary RDS endpoint"
echo "4. Verify primary ALB is healthy before switching traffic back"

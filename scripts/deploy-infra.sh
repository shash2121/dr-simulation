#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────
# DR Simulation - Full Automated Deployment
#
# Deploys primary and DR regions with VPC peering in one go.
# Run from the dr-simulation directory.
#
# Usage: ./scripts/deploy.sh
# ─────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

PRIMARY_TFVARS="primary-us-east-1.tfvars"
DR_TFVARS="dr-us-east-2.tfvars"

# ─────────────────────────────────────────────────────────
# Step 0: Initialize Terraform
# ─────────────────────────────────────────────────────────
echo "=== Step 0: Initialize Terraform ==="
terraform init -reconfigure

# ─────────────────────────────────────────────────────────
# Step 1: Apply Primary Infra (skip peering)
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 1: Deploy primary region (us-east-1) ==="

echo "Checking default workspace..."
terraform workspace select default 2>/dev/null || terraform workspace new default

echo "Applying all primary infra (excluding VPC peering)..."
terraform apply \
  -var-file="$PRIMARY_TFVARS" \
  -auto-approve \
  -target=module.vpc \
  -target=module.rds \
  -target=module.redis \
  -target=module.sqs \
  -target=module.secrets_manager \
  -target=module.eks \
  -target=module.acm \
  -target=module.route53 \
  -target=module.ec2

echo "Primary region deployed."

# ─────────────────────────────────────────────────────────
# Get Route53 zone ID from primary
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Fetch Route53 zone ID ==="
# Refresh outputs first (hosted_zone_id may be new after target apply)
terraform refresh -var-file="$PRIMARY_TFVARS" -target=module.route53 2>/dev/null || true
ZONE_ID=$(terraform output -raw hosted_zone_id 2>/dev/null)
if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" = "null" ]; then
  echo "ERROR: hosted_zone_id is empty or null."
  echo "Check that domain_name is set and module.route53 was created."
  exit 1
fi
echo "Zone ID: $ZONE_ID"

# ─────────────────────────────────────────────────────────
# Step 2: DR workspace, update zone ID
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 2: Prepare DR workspace (us-east-2) ==="

terraform workspace select dr 2>/dev/null || terraform workspace new dr
terraform init -reconfigure

DR_ZONE_LINE=$(grep -n 'hosted_zone_id' "$DR_TFVARS" | head -1 | cut -d: -f1)
sed -i '' "${DR_ZONE_LINE}s|hosted_zone_id.*=.*|hosted_zone_id            = \"$ZONE_ID\"|" "$DR_TFVARS"
echo "Updated hosted_zone_id in $DR_TFVARS to: $ZONE_ID"

# ─────────────────────────────────────────────────────────
# Step 3: Apply DR Infra (no Route53)
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 3: Deploy DR region (us-east-2) ==="

terraform apply \
  -var-file="$DR_TFVARS" \
  -auto-approve \
  -target=module.vpc \
  -target=module.rds \
  -target=module.redis \
  -target=module.sqs \
  -target=module.secrets_manager \
  -target=module.eks \
  -target=module.acm \
  -target=module.ec2

echo "DR region deployed."

# ─────────────────────────────────────────────────────────
# Step 4: Fetch DR VPC and Route Table IDs
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 4: Collect DR VPC details for peering ==="

DR_VPC_ID=$(terraform output -json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('vpc_id',{}).get('value',''))")
if [ -z "$DR_VPC_ID" ] || [ "$DR_VPC_ID" = "null" ]; then
  echo "ERROR: Failed to get DR VPC ID from outputs"
  exit 1
fi

PRIVATE_RT_OUT=$(terraform state show 'module.vpc.aws_route_table.private_rt' 2>&1) || { echo "ERROR: $PRIVATE_RT_OUT"; exit 1; }
DR_PRIVATE_RT=$(echo "$PRIVATE_RT_OUT" | grep 'id ' | head -1 | awk -F'"' '{print $2}')

PUBLIC_RT_OUT=$(terraform state show 'module.vpc.aws_route_table.public_rt' 2>&1) || { echo "ERROR: $PUBLIC_RT_OUT"; exit 1; }
DR_PUBLIC_RT=$(echo "$PUBLIC_RT_OUT" | grep 'id ' | head -1 | awk -F'"' '{print $2}')

echo "DR VPC:       $DR_VPC_ID"
echo "DR Private RT: $DR_PRIVATE_RT"
echo "DR Public RT:  $DR_PUBLIC_RT"

# ─────────────────────────────────────────────────────────
# Step 5: Apply Peering from Primary
# ─────────────────────────────────────────────────────────
echo ""
echo "=== Step 5: Set up VPC peering ==="

terraform workspace select default

echo "Updating $PRIMARY_TFVARS with DR VPC details..."
PRIMARY_VPC_LINE=$(grep -n 'peer_vpc_id' "$PRIMARY_TFVARS" | head -1 | cut -d: -f1)
PRIMARY_PRIVATE_RT_LINE=$(grep -n 'peer_route_table_id' "$PRIMARY_TFVARS" | head -1 | cut -d: -f1)
PRIMARY_PUBLIC_RT_LINE=$(grep -n 'peer_public_route_table_id' "$PRIMARY_TFVARS" | head -1 | cut -d: -f1)

sed -i '' "${PRIMARY_VPC_LINE}s|peer_vpc_id.*=.*|peer_vpc_id         = \"$DR_VPC_ID\"|" "$PRIMARY_TFVARS"
sed -i '' "${PRIMARY_PRIVATE_RT_LINE}s|peer_route_table_id.*=.*|peer_route_table_id        = \"$DR_PRIVATE_RT\"|" "$PRIMARY_TFVARS"
sed -i '' "${PRIMARY_PUBLIC_RT_LINE}s|peer_public_route_table_id.*=.*|peer_public_route_table_id = \"$DR_PUBLIC_RT\"|" "$PRIMARY_TFVARS"

echo "Applying VPC peering..."
terraform apply \
  -var-file="$PRIMARY_TFVARS" \
  -auto-approve \
  -target=module.vpc_peering

echo "VPC peering active."

# ─────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────

# DR Simulation — Cross-Region Disaster Recovery on AWS

A complete infrastructure-as-code project that demonstrates cross-region disaster recovery using AWS services. Deploys a fully functional application stack (EKS + RDS MySQL + ElastiCache Redis + SQS + Secrets Manager) in two regions with a glassmorphism UI dashboard for monitoring replication and failover.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRIMARY REGION (us-east-1)               │
│                                                                 │
│  ┌─────────┐    ┌──────────────┐    ┌──────────────────────┐   │
│  │  EKS    │───▶│  RDS MySQL   │◀───│  Secrets Manager     │   │
│  │ Cluster │    │  (master)    │    │  (RDS credentials)   │   │
│  └────┬────┘    └──────┬───────┘    └──────────────────────┘   │
│       │                │                                       │
│  ┌────┴────┐    ┌──────┴───────┐    ┌──────────────────────┐   │
│  │  ALB    │    │  ElastiCache │    │  SQS Queue           │   │
│  │  (LBC)  │    │  Redis       │    │  (event ingestion)   │   │
│  └─────────┘    └──────────────┘    └──────────────────────┘   │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Flask App (Glassmorphism UI)                           │   │
│  │  - Health checks for DB, Redis, SQS                     │   │
│  │  - Event ingestion via SQS → background poller → MySQL  │   │
│  │  - Redis cache for recent events + rate tracking        │   │
│  │  - Paginated event viewer with slider navigation        │   │
│  └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
                    AWS Backbone Network
                              │
┌─────────────────────────────────────────────────────────────────┐
│                        DR REGION (us-east-2)                    │
│                                                                 │
│  Same stack: EKS + RDS MySQL + Redis + SQS + Secrets Manager   │
│  RDS acts as cross-region read replica of primary              │
│                                                                 │
│  On failover: promote replica → standalone → accept writes     │
└─────────────────────────────────────────────────────────────────┘
```

## Infrastructure Components

| Component | Service | Purpose |
|---|---|---|
| **VPC** | Custom VPC (3 AZs) | Network isolation, public/private subnets, NAT Gateway |
| **EKS** | Managed Kubernetes | Container orchestration for the Flask app |
| **RDS** | MySQL 8.0 (db.t4g.micro) | Primary datastore with cross-region replication |
| **ElastiCache** | Redis 7.0 (cache.t3.small) | Event cache, rate tracking, failover metadata |
| **SQS** | Standard Queue | Asynchronous event ingestion |
| **Secrets Manager** | RDS credentials | Secure credential storage, mounted via CSI driver |
| **ALB** | AWS Load Balancer Controller | Ingress routing via Kubernetes Ingress |
| **EC2** | t3.micro | Bastion/utility instance |

## Kubernetes Addons (deployed via Helm)

- **AWS Load Balancer Controller** — provisions ALB from Ingress resources
- **Secrets Store CSI Driver** — mounts Secrets Manager secrets as K8s secrets
- **AWS Secrets Provider** — integrates CSI driver with AWS Secrets Manager
- **EKS Pod Identity Agent** — IAM authentication for pods (no IRSA needed)

## Project Structure

```
dr-simulation/
├── main.tf                     # Root Terraform configuration
├── variables.tf                # Input variables
├── outputs.tf                  # Terraform outputs
├── providers.tf                # AWS, Kubernetes, Helm providers
├── backend.tf                  # Backend configuration
├── primary-us-east-1.tfvars    # Primary region variables
├── dr-us-east-2.tfvars         # DR region variables
│
├── modules/
│   ├── vpc/                    # VPC, subnets, NAT, IGW, DB subnet group
│   ├── rds/                    # RDS MySQL instance + security group
│   ├── redis/                  # ElastiCache Redis cluster
│   ├── sqs/                    # SQS queue
│   ├── secrets-manager/        # Secrets Manager secret + version
│   ├── eks/                    # EKS cluster, node group, Pod Identity, Helm addons
│   ├── ec2/                    # EC2 instance (bastion/utility)
│   ├── acm/                    # ACM certificate (optional, with domain)
│   ├── route53/                # Route53 hosted zone (optional)
│   └── aws-policies/           # IAM policy documents
│
├── app/
│   ├── main.py                 # Flask application
│   ├── requirements.txt        # Python dependencies
│   ├── Dockerfile              # Multi-stage Docker build
│   ├── templates/index.html    # Glassmorphism UI dashboard
│   ├── k8s-manifests/          # Kubernetes manifests for PRIMARY region
│   │   ├── configmap.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── serviceaccount.yaml
│   │   └── secretproviderclass.yaml
│   └── k8s-manifests-dr/       # Kubernetes manifests for DR region
│       ├── configmap.yaml      # (us-east-2, dr-redis, dr-orders-queue)
│       ├── secretproviderclass.yaml  # (dr-rds-credentials)
│       └── ...                 # (same as primary)
│
└── scripts/
    ├── data-generator.sh       # Pushes random events to the app
    ├── build-and-push.sh       # Builds and pushes Docker image
    ├── failover.sh             # Promotes DR RDS replica to standalone
    ├── failback.sh             # Restores primary region from DR snapshot
    └── simulate-failure.sh     # Simulates primary region failure
```

## Prerequisites

- **Terraform** >= 1.3
- **AWS CLI** configured with appropriate credentials
- **kubectl** configured for EKS clusters
- **Docker** for building the application image
- **SSH key pairs** in both regions (`useast` in us-east-1, `useast2` in us-east-2)

## Quick Start

Workspaces are used to keep state separate between regions.

### 1. Deploy Primary Region (us-east-1)

```bash
terraform workspace select default
terraform init
terraform apply -var-file=primary-us-east-1.tfvars -auto-approve
```

### 2. Deploy DR Region (us-east-2)

```bash
terraform workspace select dr
terraform init
terraform apply -var-file=dr-us-east-2.tfvars -auto-approve
```

### 3. Set Up VPC Peering

Update `primary-us-east-1.tfvars` with DR VPC details:

```bash
# Get DR VPC info
terraform workspace select dr
terraform output -json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['vpc_id']['value'])"

# Fill in peer_vpc_id, peer_vpc_cidr, peer_region, peer_route_table_id,
# peer_public_route_table_id in primary-us-east-1.tfvars

# Then apply peering from primary
terraform workspace select default
terraform apply -var-file=primary-us-east-1.tfvars -auto-approve
```

### 4. Configure kubectl

```bash
# Primary
aws eks update-kubeconfig --name primary --region us-east-1

# DR
aws eks update-kubeconfig --name dr --region us-east-2
```

### 4. Deploy Application

```bash
# Primary region
kubectl apply -f app/k8s-manifests/

# DR region
kubectl apply -f app/k8s-manifests-dr/
```

### 5. Build and Push Docker Image

```bash
docker build -t sha2121/dr-sim-app:latest --platform linux/amd64 -f app/Dockerfile app/
docker push sha2121/dr-sim-app:latest
```

### 6. Generate Test Data

```bash
ALB=$(kubectl get ingress dr-sim-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
bash scripts/data-generator.sh "http://$ALB" 2
```

### 7. Access the Dashboard

Open the ALB URL in your browser:
```bash
echo "http://$(kubectl get ingress dr-sim-ingress -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

## Dashboard Features

The glassmorphism UI dashboard shows:

- **Region** — Current AWS region and pod hostname
- **MySQL** — Connection status + endpoint (e.g., `primary-rds.xxx.us-east-1.rds.amazonaws.com:3306`)
- **Redis** — Connection status + endpoint
- **SQS** — Connection status + queue URL
- **Redis Cache** — Cached event count, events/min rate, last sync time (IST)
- **SQS Queue** — Visible messages, in-flight, processed, errors
- **Events** — Paginated event cards (5 at a time) with slider navigation, latest first
- **Failover Status** — Cache size, events/min, last sync time, last event ID

## Cross-Region RDS Replication

This project uses **MySQL binlog replication** for cross-region data replication. VPC peering is required to allow the DR RDS to connect to the Primary RDS over private IPs.

### How It Works

1. **Primary RDS** (us-east-1) is the master instance accepting reads and writes
2. **DR RDS** (us-east-2) connects to primary via `mysql.rds_set_external_master` and acts as a replica
3. Replication is **one-way**: Primary → DR
4. On failover, roles are **reversed** — DR becomes master, primary becomes replica

### Prerequisites

- **VPC Peering** between primary and DR VPCs (see tfvars `peer_vpc_id`, `peer_region`)
- Both RDS security groups must allow inbound port 3306 from the **other region's VPC CIDR**:
  - **Primary SG**: allow `10.1.0.0/16` (DR VPC)
  - **DR SG**: allow `10.0.0.0/16` (Primary VPC)
- Both RDS instances need `backup_retention_period >= 1` to enable binary logging
- Both RDS instances need `binlog_format = ROW` (via parameter group)
- **Important**: Free tier `db.t3.micro` does NOT support backups. Use `db.t4g.micro` or higher

### How to Connect to RDS MySQL

Install the MySQL client on your machine:

```bash
# macOS
brew install mysql-client
export PATH="/opt/homebrew/opt/mysql-client/bin:$PATH"

# Ubuntu/Debian
sudo apt install mysql-client

# Amazon Linux / RHEL
sudo yum install mysql
```

Connect to any RDS instance:

```bash
mysql -h <rds-endpoint> -P 3306 -u admin -p
# Enter password when prompted
```

### Step 1: Verify Binary Logging on Primary

Connect to the **Primary RDS** (us-east-1):

```bash
mysql -h primary-rds.<id>.us-east-1.rds.amazonaws.com -P 3306 -u admin -p
```

Check that binary logging is enabled:

```sql
SHOW VARIABLES LIKE 'binlog_format';
-- Must return: ROW
```

### Step 2: Create Replication User on Primary

On the **Primary RDS**, run:

```sql
CREATE USER 'repl_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
```

### Step 3: Get Binary Log Position from Primary

Binary logs are only created when there are writes. If the database is empty, generate a write first:

```sql
-- On Primary RDS:
CREATE DATABASE IF NOT EXISTS dummydb;
USE dummydb;
CREATE TABLE IF NOT EXISTS binlog_trigger (id INT AUTO_INCREMENT PRIMARY KEY, ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
INSERT INTO binlog_trigger VALUES ();
```

Then get the current binlog position:

```sql
SHOW MASTER STATUS;
-- Returns: mysql-bin-changelog.000004 | 544
```

Note the **File** and **Position** values — you'll need them in the next step.

### Step 4: Start Replication on DR

Connect to the **DR RDS** (us-east-2):

```bash
mysql -h dr-rds.<id>.us-east-2.rds.amazonaws.com -P 3306 -u admin -p
```

Then run (replace file and position with values from Step 3):

```sql
CALL mysql.rds_set_external_master (
  'primary-rds.<id>.us-east-1.rds.amazonaws.com',
  3306,
  'repl_user',
  '<strong-password>',
  'mysql-bin-changelog.000004',   -- from SHOW MASTER STATUS
  544,                             -- from SHOW MASTER STATUS
  0
);

CALL mysql.rds_start_replication;
```

### Step 5: Verify Replication

On the **DR RDS**, run:

```sql
SHOW SLAVE STATUS\G
```

Check that:
- `Slave_IO_Running: Yes`
- `Slave_SQL_Running: Yes`
- `Seconds_Behind_Master: 0` (or a small number)

**Troubleshooting:**

| Issue | Check |
|---|---|
| `Slave_IO_Running: Connecting` | VPC peering active? SG rules present? |
| `Last_IO_Error: Binary log is not open` | Binlog file/position correct? Re-run `SHOW MASTER STATUS` on primary |
| `SHOW MASTER STATUS` empty | Writes happened? `backup_retention_period >= 1`? `binlog_format = ROW`? |

---

## Failover — Reverse Roles (DR becomes Master)

When the primary region goes down, reverse the replication direction so DR becomes the new master.

### Step 1: Stop Replication on DR

Connect to the **DR RDS** (us-east-2):

```bash
mysql -h dr-rds.<id>.us-east-2.rds.amazonaws.com -P 3306 -u admin -p
```

Then run:

```sql
CALL mysql.rds_stop_replication;
CALL mysql.rds_reset_external_master;
```

### Step 2: Create Replication User on DR

On the **DR RDS**, run:

```sql
CREATE USER 'repl_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
```

### Step 3: Get Binlog Position from DR

On the **DR RDS**:

```sql
SHOW MASTER STATUS;
-- Note the File and Position values
```

### Step 4: Point Primary as Replica of DR

Connect to the **Primary RDS** (us-east-1):

```bash
mysql -h primary-rds.<id>.us-east-1.rds.amazonaws.com -P 3306 -u admin -p
```

Then run (use values from Step 3):

```sql
CALL mysql.rds_stop_replication;
CALL mysql.rds_reset_external_master;

CALL mysql.rds_set_external_master (
  'dr-rds.<id>.us-east-2.rds.amazonaws.com',
  3306,
  'repl_user',
  '<strong-password>',
  '<dr_binlog_file>',
  <dr_binlog_position>,
  0
);

CALL mysql.rds_start_replication;
```

### Step 5: Verify

On the **Primary RDS** (now replica):

```sql
SHOW SLAVE STATUS\G
```

### Step 6: Update App Configuration

- Update Secrets Manager in both regions with the DR RDS endpoint
- Restart EKS pods in DR region:
  ```bash
  kubectl rollout restart deployment dr-sim-app
  ```

---

## Failback — Restore Primary as Master

Once the original primary region is restored, reverse the roles back.

### Step 1: Stop Replication on Primary

Connect to the **Primary RDS** (us-east-1):

```bash
mysql -h primary-rds.<id>.us-east-1.rds.amazonaws.com -P 3306 -u admin -p
```

Then run:

```sql
CALL mysql.rds_stop_replication;
CALL mysql.rds_reset_external_master;
```

### Step 2: Create Replication User on Primary

On the **Primary RDS**, run:

```sql
CREATE USER 'repl_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
```

### Step 3: Get Binlog Position from Primary

On the **Primary RDS**:

```sql
SHOW MASTER STATUS;
```

### Step 4: Point DR as Replica of Primary

Connect to the **DR RDS** (us-east-2):

```bash
mysql -h dr-rds.<id>.us-east-2.rds.amazonaws.com -P 3306 -u admin -p
```

Then run:

```sql
CALL mysql.rds_stop_replication;
CALL mysql.rds_reset_external_master;

CALL mysql.rds_set_external_master (
  'primary-rds.<id>.us-east-1.rds.amazonaws.com',
  3306,
  'repl_user',
  '<strong-password>',
  '<primary_binlog_file>',
  <primary_binlog_position>,
  0
);

CALL mysql.rds_start_replication;
```

### Step 5: Update App Configuration

- Update Secrets Manager in both regions with the primary RDS endpoint
- Restart EKS pods in both regions:
  ```bash
  kubectl rollout restart deployment dr-sim-app
  ```

---

## Important Notes

### RDS Cross-Region Replication

| Feature | Behavior |
|---|---|
| **VPC Peering Required?** | Yes — binlog replication needs private IP connectivity |
| **Replication Type** | Binlog-based (physical) for MySQL |
| **DDL Replication** | ✅ Automatic (CREATE TABLE, ALTER TABLE, etc.) |
| **Replica State** | Read-only during replication |
| **Failover** | Stop replica → start new master → reverse replication direction |

### Security Groups for Cross-Region Access

Each RDS security group must allow inbound on port 3306 from the **other region's VPC CIDR**:

- **Primary SG**: allow `10.1.0.0/16` (DR VPC)
- **DR SG**: allow `10.0.0.0/16` (Primary VPC)

### Redis Behavior

- Redis is **NOT replicated** across regions
- Cache is **lost on failover** — this is intentional to demonstrate the trade-off
- MySQL retains all data; Redis cache rebuilds from new events
- Dashboard shows "Cache is NOT replicated — resets on failover"

### Cost Optimization

- RDS uses `db.t4g.micro` with `backup_retention_period = 1` (required for binlog)
- `db.t3.micro` does NOT support backups on free tier — use `db.t4g.micro` instead
- Recovery window for Secrets Manager is `0` (immediate deletion on destroy)

## Cleanup

```bash
# Primary region
terraform destroy -var-file=primary-us-east-1.tfvars -auto-approve

# DR region
terraform destroy -var-file=dr-us-east-2.tfvars -auto-approve
```

# Cross-Region Disaster Recovery on AWS: An EKS Simulation

**Building a production-like disaster recovery simulation with Terraform, EKS, and manual MySQL replication.**

---

## Why We Built This

Disaster recovery is one of those things you don't fully understand until you've actually done it. Reading about cross-region replication is easy; standing up a full stack, watching it break, and manually failing it over is what makes the concepts stick.

We built a complete DR simulation on AWS that mirrors a real production setup: a Flask application running on EKS, backed by RDS MySQL, ElastiCache Redis, SQS, and Secrets Manager — deployed across two regions (`us-east-1` primary, `us-east-2` DR). The stack is wired together with Terraform, exposed via ALB, and monitored through a glassmorphism UI dashboard.

This post walks through the architecture, the replication mechanics, and the gotchas we hit along the way.

---

## Architecture at a Glance

The entire stack lives in a single Terraform repository, split by workspace:

| Workspace | Region | Purpose |
|---|---|---|
| `default` | `us-east-1` | Primary stack |
| `dr` | `us-east-2` | DR stack |

Both workspaces consume region-specific `.tfvars` files. The modules are reused: VPC, EKS, RDS MySQL, ElastiCache Redis, SQS, Secrets Manager, ACM, and Route53.

**Key design choices:**
- **EKS Pod Identity** for pod-level IAM auth — simpler than IRSA, no OIDC provider juggling.
- **ALB via Ingress** — the AWS Load Balancer Controller provisions the ALB from a Kubernetes Ingress resource, not a Terraform module.
- **VPC Peering** — the primary and DR VPCs are peered so RDS instances can talk over private IPs. This is required for MySQL binlog replication.
- **Route53 in primary only** — one hosted zone, validated by ACM certs in both regions.

The application itself is a Flask service with a glassmorphism UI that shows MySQL health, Redis cache stats, SQS queue depth, and paginated events. It's not a toy — it has real data flow: SQS ingestion, background polling, MySQL persistence, and Redis caching.

---

## The Replication Setup

We chose **manual MySQL binlog replication** over native RDS cross-region read replicas. Why? Because it forces you to understand the mechanics — binlog files, positions, replication users, and the stored procedures RDS wraps around them.

### Prerequisites

Before replication works, a few things must line up:

1. **`binlog_format = ROW`** — set via a custom RDS parameter group.
2. **`backup_retention_period >= 1`** — binary logging is only enabled when backups are on. This is a silent trap: `db.t3.micro` on the free tier *ignores* this setting. We switched to `db.t4g.micro`.
3. **VPC Peering routes** — both public and private route tables in each VPC need routes to the peered CIDR. EC2 lives in public subnets; RDS lives in private subnets.
4. **Security groups** — each RDS security group must allow inbound port 3306 from the *other* region's VPC CIDR block.

### The Replication Dance

Once the infrastructure is up, replication is a sequence of SQL calls:

**On the Primary:**
```sql
CREATE USER 'repl_user'@'%' IDENTIFIED BY '<strong-password>';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'repl_user'@'%';
FLUSH PRIVILEGES;
```

Then force a write (empty databases don't have binlogs):
```sql
CREATE DATABASE IF NOT EXISTS dummydb;
USE dummydb;
CREATE TABLE binlog_trigger (id INT AUTO_INCREMENT PRIMARY KEY, ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP);
INSERT INTO binlog_trigger VALUES ();
```

Check the position:
```sql
SHOW MASTER STATUS;
-- Returns: mysql-bin-changelog.000004 | 544
```

**On the DR:**
```sql
CALL mysql.rds_set_external_master (
  'primary-rds.<id>.us-east-1.rds.amazonaws.com',
  3306,
  'repl_user',
  '<strong-password>',
  'mysql-bin-changelog.000004',
  544,
  0
);
CALL mysql.rds_start_replication;
```

Verify:
```sql
SHOW SLAVE STATUS\G
-- Slave_IO_Running: Yes
-- Slave_SQL_Running: Yes
-- Seconds_Behind_Master: 0
```

---

## Failover: Reversing the Arrow

When the primary region fails, you manually promote DR to standalone and reverse the replication direction.

**On the DR:**
```sql
CALL mysql.rds_stop_replication;
CALL mysql.rds_reset_external_master;
```

*(Note: `rds_reset_replication` does not exist. It's `rds_reset_external_master` — we learned this the hard way.)*

Create a new replication user on DR, get the new `SHOW MASTER STATUS` position, then point the old primary back as a replica:

**On the old Primary:**
```sql
CALL mysql.rds_stop_replication;
CALL mysql.rds_reset_external_master;

CALL mysql.rds_set_external_master (
  'dr-rds.<id>.us-east-2.rds.amazonaws.com',
  3306,
  'repl_user',
  '<strong-password>',
  '<dr-binlog-file>',
  <dr-binlog-position>,
  0
);
CALL mysql.rds_start_replication;
```

Then update the application: swap the RDS endpoint in Secrets Manager, roll the EKS pods, and update the DNS record to point to the DR ALB.

---

## Failback: Restoring the Original Primary

Once the original region is healthy, the process is the exact reverse. Stop replication on the old primary, promote it back to master, get its binlog position, and point the DR region back as a replica. The stored procedures are the same — the direction is the only thing that changes.

---

## The Dashboard

The application UI is intentionally visual. It shows:

- **MySQL endpoint** and connection status
- **Redis cache size**, events-per-minute rate, and last sync time
- **SQS queue depth** — visible, in-flight, and processed messages
- **Paginated event cards** — latest first, with slider navigation

One intentional design choice: **Redis is not replicated across regions**. Cache is lost on failover. MySQL retains all data; Redis rebuilds from new events. This makes the trade-off visible — caching is a performance optimization, not a durability guarantee.

---

## Lessons Learned

| Gotcha | What We Did |
|---|---|
| `db.t3.micro` + free tier | Silently ignores `backup_retention_period`. Use `db.t4g.micro`. |
| `SHOW MASTER STATUS` empty | No writes yet, or `backup_retention_period` not applied. |
| `rds_reset_replication` | Doesn't exist. Use `rds_reset_external_master`. |
| VPC Peering stale routes | Terraform state can hold stale route IDs after VPC recreation. |
| ACM certs | Regional — need one per region, but one Route53 zone validates both. |
| `terraform_remote_state` | Avoided for cross-workspace peering values. Manual tfvars instead. |

---

## Key Takeaways

1. **Binlog replication needs both infrastructure *and* writes.** No writes means no binlog position. No VPC peering means no connectivity. Both layers must line up before replication works.

2. **Free tier hides silent failures.** `db.t3.micro` ignores backup retention settings, which silently disables binary logging. Test with the instance class you actually plan to run in production.

3. **RDS stored procedures are not vanilla MySQL.** `rds_reset_external_master` is the RDS-specific wrapper. Standard `RESET SLAVE` or imagined `rds_reset_replication` commands simply don't exist on RDS.

4. **DR isn't "deploy and forget" — it's a runbook you practice.** Terraform can provision two identical stacks in minutes, but failing over still requires a human sequence: stop replication on the standby, promote it to master, reverse the replication direction, update Secrets Manager endpoints, roll the Kubernetes pods, and swap the DNS record. Infrastructure-as-code gives you the *what*; your runbook gives you the *how*. If you can't execute that sequence under pressure without second-guessing, you haven't truly tested DR.

---

## Conclusion

Managed services are great until you need to understand what happens under the hood. Manual MySQL binlog replication across regions is more work than a native read replica, but it teaches you the exact sequence of events during a real outage: what breaks, what needs updating, and what order to do things in.

This simulation proves that cross-region DR is not just an infrastructure problem — it's a workflow problem. The Terraform modules, Kubernetes manifests, and helper scripts are all in the repository linked below.

---

**Full code and deployment scripts:** [GitHub Repository](https://github.com/your-repo/dr-simulation)

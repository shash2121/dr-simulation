# DR Simulation App

Python Flask application for demonstrating cross-region disaster recovery on AWS.

## Local Testing

### With Docker Compose (recommended)

```bash
cd app
docker compose up --build
# Open http://localhost:8080
```

This starts PostgreSQL 16, Redis 7, and the app — no AWS credentials needed.

### Without Docker

```bash
cd app

# Start PostgreSQL and Redis locally or via Docker
docker run -d --name pg -e POSTGRES_USER=dbadmin -e POSTGRES_PASSWORD=password -e POSTGRES_DB=dummydb -p 5432:5432 postgres:16-alpine
docker run -d --name rd -p 6379:6379 redis:7-alpine

# Install dependencies
pip install -r requirements.txt

# Run
DB_HOST=localhost DB_PORT=5432 DB_NAME=dummydb DB_USERNAME=dbadmin DB_PASSWORD=password REGION=local REDIS_HOST=localhost REDIS_PORT=6379 PORT=8080 python main.py
# Open http://localhost:8080
```

## Data Generator

Push random dummy events to populate the database:

```bash
# Local
./scripts/data-generator.sh http://localhost:8080

# Against EKS ALB
./scripts/data-generator.sh http://<alb-dns-name> 5

# Run in background
./scripts/data-generator.sh http://localhost:8080 3 &
```

Generates random e-commerce style events (purchases, returns, shipments) every N seconds contai of random products and users.

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Glassmorphism dashboard UI |
| `/health` | GET | Health check — DB, Redis, SQS status (used by ALB target group) |
| `/write` | POST | Write an event to PostgreSQL `{"data": "message"}` |
| `/read` | GET | Read last 30 events from PostgreSQL |
| `/redis-test` | GET | Increment Redis counter (resets on DR failover — by design) |

## Environment Variables

| Variable | Default | Source |
|----------|---------|--------|
| `DB_HOST` | `localhost` | `db-credentials` Secret (synced from Secrets Manager via CSI) |
| `DB_PORT` | `5432` | `db-credentials` Secret |
| `DB_NAME` | `dummydb` | `db-credentials` Secret |
| `DB_USERNAME` | `dbadmin` | `db-credentials` Secret |
| `DB_PASSWORD` | — | `db-credentials` Secret |
| `REGION` | `unknown` | ConfigMap `app-config` |
| `REDIS_HOST` | `localhost` | ConfigMap `app-config` |
| `REDIS_PORT` | `6379` | ConfigMap `app-config` |
| `SQS_QUEUE_URL` | (empty) | ConfigMap `app-config` (optional, skipped if not set) |
| `PORT` | `8080` | Set in Deployment pod spec |

## Build & Push

```bash
docker build -t dr-sim-app:latest .
docker tag dr-sim-app:latest <account>.dkr.ecr.<region>.amazonaws.com/dr-sim-app:latest
docker push <account>.dkr.ecr.<region>.amazonaws.com/dr-sim-app:latest
```

## K8s Manifests

Apply these after Terraform provisions the EKS cluster:

```bash
kubectl apply -f k8s-manifests/configmap.yaml
kubectl apply -f k8s-manifests/secretproviderclass.yaml
kubectl apply -f k8s-manifests/ingress.yaml
```

## DR Demo Flow

1. **Run data generator** on the primary region's app URL
2. **Simulate failure** — block primary ALB/Ingress
3. **DNS failover** — traffic routes to DR region
4. **Read events on DR** — previously written events appear (PostgreSQL cross-region replication)
5. **Redis counter** resets to 0 — Redis is not replicated (expected ephemeral cache behavior)
6. **SQS** — independent per region; queues don't replicate
7. The dashboard shows which region is currently serving and connectivity status in real-time

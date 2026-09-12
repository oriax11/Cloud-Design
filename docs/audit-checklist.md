# Cloud-Design Audit Checklist

Mapping of the subject (`docs/cloud-design.md`) and audit
(`docs/cloud-design-audit.md`) against the implementation.

Legend: ✅ done · ⚠️ partial · ❌ missing · — not applicable

Last verified: 2026-09-12 (account `006631837921`, `us-east-1`).

---

## 1. Subject requirements

### 1.1 Components (architecture)

| Requirement | Status | Evidence |
|-------------|--------|----------|
| `inventory-db` PostgreSQL container, port 5432 | ✅ | `module.efs` + `aws_ecs_task_definition.inventory_db`; private subnet |
| `billing-db` PostgreSQL container, port 5432 | ✅ | `aws_ecs_task_definition.billing_db`; private subnet |
| `inventory-app` container, connects to DB, port 8080 | ✅ | `GET/POST /api/movies` → 200/201 |
| `billing-app` container, connects to DB + consumes RabbitMQ, port 8080 | ✅ | consumed message → `billing-db.orders` |
| `rabbit-queue` RabbitMQ container | ✅ | `cloud-design-rabbit-queue` running; queue `billing_queue` |
| `api-gateway-app` container, forwards requests, port 3000 | ✅ | ALB → gateway → inventory/rabbit |

### 1.2 Design criteria

| Criterion | Status | Evidence |
|-----------|--------|----------|
| Scalability | ✅ | ECS Service Auto Scaling (CPU 70%, min 2 / max 4); scaled 2→3 under load |
| Availability | ⚠️ | Hybrid: stateless active-active (2/AZ); stateful single-active (documented tradeoff) |
| Security | ✅ | Private subnets, TLS/ACM, Cognito JWT, Secrets Manager, least-privilege SGs; DBs VPC-only |
| Cost-effectiveness | ✅ | ~$70 for 15 days; single NAT, Docker Hub, EFS consolidation |
| Simplicity | ✅ | Managed Fargate, Service Connect, one EFS |

### 1.3 Delivery requirements

| Requirement | Status | Evidence |
|-------------|--------|----------|
| Cost: understand pricing | ✅ | `docs/architecture-justification.md`, README cost table |
| Cost: monitor usage + billing alerts | ✅ | `terraform/budget.tf` → AWS Budget `cloud-design-monthly` with email alerts |
| Cost: clean up resources | ✅ | `scripts/cleanup.sh` (`terraform destroy`) |
| Infrastructure as Code (Terraform) | ✅ | `terraform/` with `modules/{vpc,security,efs,alb,ecs}` |
| Networking / storage provisioned as code | ✅ | VPC, subnets, NAT, EFS |
| Containerize with optimized Dockerfiles | ✅ | `docker/*/Dockerfile` + `docker-compose.yml`; source in `srcs/` |
| Deploy with ECS/EKS + load balancing | ✅ | ECS Fargate + ALB |
| Secure service-to-service communication | ✅ | Service Connect + security groups |
| Monitoring and logging | ✅ | CloudWatch Logs + Container Insights + dashboard |
| Auto-scaling + load testing | ✅ | 3 target-tracking policies; load test evidence `monitoring/load-test.txt` |
| HTTPS via ACM | ✅ | Self-signed cert imported, `:443` listener, 80→443 redirect |
| Secure API endpoints / managed authentication | ✅ | Cognito user pool; JWT enforced on `/api/*` |
| Vulnerability scanning | ✅ | Trivy scans in `monitoring/trivy-scan.txt` (findings + remediation below) |
| Databases accessible only from the VPC | ✅ | Private subnets, no public IPs, scoped SGs |
| Documentation (`README.md`) | ✅ | Architecture, setup, config, usage, security, cost |
| Bonus | ❌ | None implemented |

---

## 2. Audit questions

### 2.1 Repository content

| Question | Status | Notes |
|----------|--------|-------|
| Required files present | ✅ | README, source (`srcs/`), IaC (`terraform/`), containerization (`docker/`), scripts |

### 2.2 Role-play (14 questions)

| Question | Status |
|----------|--------|
| ...all 14 stakeholder questions | ⚠️ Prepared via `docs/architecture-justification.md`; rehearsal pending |

### 2.3 Architecture design (5 criteria)

| Question | Status | Notes |
|----------|--------|-------|
| Aligns with requirements | ✅ | See 1.2 |
| Cost-effective | ✅ | ~$70 / 15 days |

### 2.4 Documentation

| Question | Status |
|----------|--------|
| README has prerequisites/setup/config/usage | ✅ |
| Clear + complete with diagrams | ✅ | Mermaid architecture diagram + component table |

### 2.5 Verify deployment

| Question | Status | Evidence |
|----------|--------|----------|
| Proper `aws cli` / ECS commands | ✅ | `aws ecs list-services` / `describe-tasks` |
| All microservices running, no errors | ✅ | 9 tasks running; 30,600 API calls, 0 errors |
| Load balancing configured | ✅ | ALB, 2+ healthy targets, traffic distributed |
| Secure inter-service communication | ✅ | Service Connect + SGs |

### 2.6 API functionality through the gateway

| Question | Status | Evidence |
|----------|--------|----------|
| POST movie returns success | ✅ | `201 Created` |
| GET movies returns expected data | ✅ | `200` with movie list |

### 2.7 Billing resilience

| Question | Status | Evidence |
|----------|--------|----------|
| Send billing request while billing is stopped | ✅ | `200`, queued in `billing_queue` |
| Queued request processed after restart | ✅ | order row written to `billing-db` |

### 2.8 Terraform

| Question | Status | Evidence |
|----------|--------|----------|
| Terraform provisions/manages resources | ✅ | `terraform plan` → No changes |
| Infrastructure follows the design | ✅ | Modules per architecture |

### 2.9 Containerization / orchestration

| Question | Status | Notes |
|----------|--------|-------|
| Optimized Dockerfiles | ✅ | `docker/*/Dockerfile` (multi-stage not used by these simple Python images; slim `python:3.12-alpine`) |
| Orchestration configured correctly | ✅ | ECS task definitions + services (exported to `ecs/task-definitions/`) |

### 2.10 Monitoring and logging

| Question | Status | Evidence |
|----------|--------|----------|
| Dashboards give useful insights | ✅ | CPU/memory, ALB requests/latency/5XX, running tasks |

### 2.11 Optimization

| Question | Status | Notes |
|----------|--------|-------|
| Auto-scaling configured | ✅ | 3 target-tracking policies; verified 2→3 scale-out |
| Efficient under load scenarios | ✅ | 600 @ 60 concurrency and 30,000 sustained, all HTTP 200 |

### 2.12 Security

| Question | Status | Notes |
|----------|--------|-------|
| HTTPS, secure endpoints, VPC DB access, scanning | ✅ | HTTPS/VPC/Cognito + Trivy evidence |
| Unauthenticated request rejected | ✅ | `401` without/invalid token |
| Demonstrate Cognito configuration | ✅ | User pool + app client + JWKS validation |

### 2.13 Bonus

| Question | Status |
|----------|--------|
| Optional bonus added | ❌ |

---

## 3. Remaining items / findings

| # | Item | Impact | Notes |
|---|------|--------|-------|
| 1 | Rebuild `oriax11/api-gateway-app` | Cleanup | Removes `gateway-patch.py` startup workaround |
| 2 | Rebuild `inventory-app` / `billing-app` with `pool_pre_ping` | Cleanup | Removes `db-pool-patch.py` workaround |
| 3 | **DB image vulnerabilities** | Security | `debian:bullseye` + `postgresql-13` → 17 CRITICAL / 94 HIGH. Remediation: rebuild on `postgres:15-alpine` (or newer, maintained base). |
| 4 | Role-play rehearsal | Audit | Practice the 14 stakeholder questions |
| 5 | Bonus feature | Optional | FaaS/CDN/alerting |

### Vulnerability scan summary (`monitoring/trivy-scan.txt`)

| Image | HIGH | CRITICAL | Secret |
|-------|------|----------|--------|
| api-gateway-app | 9 | 0 | — |
| inventory-app | 9 | 0 | — |
| billing-app | 9 | 0 | — |
| inventory-db | 94 | 17 | AsymmetricPrivateKey (Debian snakeoil cert) |
| billing-db | 94 | 17 | AsymmetricPrivateKey (Debian snakeoil cert) |

The app images are clean of CRITICAL issues. The database images carry the
Debian 11 base-image backlog and should be rebuilt on a maintained base.

---

## 4. Live verification snapshot

- ECS services: api-gateway ×2 (→3 under load), inventory ×2, billing ×2, rabbit ×1, inventory-db ×1, billing-db ×1 — all running.
- ALB: healthy targets; `:443` HTTPS (self-signed) + `:80` → 301.
- API: `GET /api/movies` → 200 with token; no token → 401; POST → 201.
- Billing: queued while down, processed on restart.
- Cognito: user pool `cloud-design-user-pool`.
- EFS: 2 encrypted file systems.
- CloudWatch: 6 log groups + `cloud-design` dashboard.
- AWS Budget: `cloud-design-monthly` ($50) with email alerts.
- `terraform plan`: No changes.

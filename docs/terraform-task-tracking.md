# Terraform Task Tracking

Status of the Terraform implementation against `docs/architecture-plan.md` and
`docs/cloud-design-audit.md`.

Last updated: 2026-09-12.

Legend: `[x]` done · `[ ]` pending · `[!]` open issue · `[~]` workaround (now removed)

**Live environment:** AWS account `006631837921`, region `us-east-1`.
ALB: `https://cloud-design-alb-1584861693.us-east-1.elb.amazonaws.com`
(HTTP `:80` → 301 redirect; self-signed cert — use `curl -k`).

---

## Deployed & verified

- [x] Repository structure matches `docs/architecture-plan.md` (`terraform/` +
      `modules/{vpc,security,efs,alb,ecs}`, `srcs/`, `docker/`, `ecs/`,
      `monitoring/`, `scripts/`). All resources migrated into modules with
      `moved` blocks (0 added / 0 changed / 0 destroyed).
- [x] `terraform init` / `fmt` / `validate` / `plan` / `apply`
      (currently **73 managed resource instances** / 69 resource blocks)
- [x] VPC `10.0.0.0/16`, IGW, 2 public + 2 private subnets, single NAT (AZ a), route tables
- [x] Security groups (per-service least privilege) + EFS SGs
- [x] Secrets Manager secret/version + execution-role read policy
- [x] IAM execution/task roles, ECS Exec policy, EFS access policy
- [x] ECS Fargate cluster, 6 task definitions (awsvpc, awslogs), Service Connect + 6 services
- [x] EFS Regional file system (single), mount targets in both AZs, two access points (uid/gid 101/103 verified)
- [x] ALB + IP target group + HTTPS listener + HTTP→HTTPS redirect
- [x] CloudWatch log groups + dashboard (CPU/memory, ALB requests/latency/5XX, running tasks)
- [x] All 6 ECS services running (stateless `desired=2`, stateful `desired=1`)
- [x] ALB targets **healthy**
- [x] `GET /api/movies` → 200; `POST /api/movies` → 201; rows in `inventory-db`
- [x] `POST /api/billing/` → 200; consumed by billing-app and written to `billing-db.orders`
- [x] **HTTPS** — self-signed cert imported to ACM, `:443` (TLSv1.2), `:80` → 301
- [x] Root route `/` → 200 `{"service":"api-gateway","status":"ok"}`
- [x] **Cognito** — user pool + app client; gateway validates RS256 JWT via JWKS on
      `/api/*`; no/invalid token → 401, valid → 200/201 (`scripts/create-test-user.sh`)
- [x] **Auto-scaling** — target-tracking 70% CPU, min 2 / max 4; verified **2 → 3** under load
- [x] **Load test** — `monitoring/load-test.txt` (30,600 requests, 0 errors, ~123 rps)
- [x] **Container Insights** enabled
- [x] **Billing/queue resilience** — queued while billing was down, processed on restart
- [x] **AWS Budget** — `cloud-design-monthly` ($50, 50/80/100% email alerts)
- [x] `terraform plan` → No changes

## Source, images & containerization

- [x] Microservice source imported into `srcs/` (gateway, inventory, billing, postgres-db, rabbitmq)
- [x] `docker/` — per-service Dockerfiles + `docker-compose.yml` + `.env.example`
- [x] **App images rebuilt and pushed** — `1ee5lim/{api-gateway-app,inventory-app,billing-app}:latest`
      with fixes **baked into the source**:
  - gateway: strip hop-by-hop headers, `/` route, Cognito JWT enforcement (`app/auth.py`)
  - inventory/billing: SQLAlchemy `pool_pre_ping` + `pool_recycle`
- [x] Task definitions updated to the new images; startup `command` overrides **removed**
      (`gateway-patch.py` / `db-pool-patch.py` deleted) — verified `hasCommand: null`
- [x] Trivy scan evidence — `monitoring/trivy-scan.txt`

## Documentation

- [x] `README.md` — architecture diagram, components, setup, config, usage, security, monitoring, cost, cleanup
- [x] `docs/audit-checklist.md` — subject/audit mapping with evidence
- [x] `docs/role-play-prep.md` — answers to the 14 stakeholder questions + live demo checklist
- [x] `docs/architecture-plan.md` / `docs/architecture-justification.md` kept in sync

---

## Open items

### Security
- [!] **DB image vulnerabilities** — `oriax11/{inventory-db,billing-db}` are built on
      `debian:bookworm`; Trivy reports **17 CRITICAL / 94 HIGH** each (unfixed base-OS
      packages). Rebuild on a maintained base (e.g. `postgres:15-alpine`) to clear it.

### Cleanup / correctness
- [x] Removed dead code: EC2/ASG/capacity-provider block in `ecs_cluster.tf`;
      unused `ecs_instance` role/attachment/instance-profile in `iam.tf`
- [x] Consolidated to **one EFS file system** with 2 access points
      (inventory data preserved; billing DB recreated on the new access point)
- [ ] Optional: remote Terraform backend (currently local state).

### Audit
- [ ] Rehearse the role-play questions (`docs/role-play-prep.md`).
- [ ] Optional bonus (FaaS / CDN / alerting).

### Ops
- [ ] Confirm the AWS Budget email subscription (click the confirmation link).

---

## Notes

- Valid billing payload schema: `{user_id, number_of_items, total_amount}`.
- Cost: leave running only while testing; `terraform destroy` (or
  `scripts/cleanup.sh`) tears it down; remove the deployer IAM user with
  `scripts/bootstrap-iam.sh --cleanup cloud-design-deployer`.
- Docker (rootless) runs from `~/bin`; daemon helper: `scripts/docker_deamon.sh`.

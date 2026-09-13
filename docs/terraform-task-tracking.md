# Terraform Task Tracking

Status of the Terraform implementation against `docs/architecture-plan.md` and `docs/cloud-design-audit.md`.
Last updated: 2026-09-11.

Legend: `[x]` done · `[ ]` pending · `[!]` bug / needs fix · `[~]` workaround in place

**Live environment:** deployed to AWS account `006631837921`, region `us-east-1`.
ALB: `http://cloud-design-alb-1969773601.us-east-1.elb.amazonaws.com`

---

## Deployed & verified (first apply)

- [x] **Repository structure matches `docs/architecture-plan.md`**: `terraform/` with
      `modules/{vpc,security,efs,alb,ecs}`, `ecs/task-definitions/`, `monitoring/`,
      `scripts/`. All 67 resources migrated into modules with `moved` blocks
      (0 added / 0 changed / 0 destroyed).

- [x] `terraform init` / `fmt` / `validate` / `plan` / `apply` — 67 resources
- [x] VPC 10.0.0.0/16, IGW, 2 public + 2 private subnets, single NAT (AZ a), route tables
- [x] Security groups (per-service least privilege) + EFS SGs
- [x] Secrets Manager secret/version + execution-role read policy
- [x] IAM execution/task roles, ECS Exec policy, EFS access policy
- [x] ECS Fargate cluster, 6 task definitions (awsvpc, awslogs), Service Connect namespace + 6 services
- [x] EFS Regional file systems, mount targets in both AZs, access points (uid/gid 101/103 verified working)
- [x] ALB + IP target group + HTTP:80 listener
- [x] CloudWatch log groups + dashboard
- [x] All 6 ECS services `desired=running=1`
- [x] ALB target **healthy**
- [x] `GET /api/movies` → 200; `POST /api/movies` → 201; movie rows in `inventory-db`
- [x] `POST /api/billing/` → 200; order consumed by billing-app and written to `billing-db` (`orders` table)
- [x] **HTTPS**: self-signed cert imported to ACM, `:443` HTTPS listener (TLSv1.2), `:80` → 301 redirect
- [x] Root route `/` → 200 `{"service":"api-gateway","status":"ok"}` (browser-friendly)
- [x] **Cognito**: user pool + app client; gateway validates RS256 JWT via pool JWKS on `/api/*`.
      No token / invalid token → 401; valid IdToken → 200/201. Test user via `scripts/create-test-user.sh`.

---

## Pre-apply fixes applied

- [x] `iam.tf` hardcoded account/secret ARN → `aws_secretsmanager_secret.app.arn`
- [x] `billing_db` service `depends_on` → billing EFS mount targets (was inventory)
- [x] Removed junk committed file `ource from state if it exists`
- [x] Added `terraform.tfvars` (gitignored) + `terraform.tfvars.example`
- [x] Added `scripts/bootstrap-iam.sh` (create/cleanup deployer IAM user)
- [x] `load_balancer.tf` health check → `/api/movies`, matcher 200 (end-to-end)

## Runtime fixes applied

- [x] `PYTHONUNBUFFERED=1` on api-gateway / inventory / billing (live logs)
- [~] **api-gateway proxy bug workaround** — the image forwards upstream hop-by-hop
  headers (`Connection`), which waitress rejects with `AssertionError` → 500s for
  clients sending `Connection: close` (incl. ALB health checks). Patched at container
  start via task-definition `command` (`sed` replaces `response.headers.items()` with
  `[]`). **Proper fix: rebuild/push `oriax11/api-gateway-app` stripping hop-by-hop
  headers, then remove the `command` override.**
- [x] Verified billing message schema is `{user_id, number_of_items, total_amount}`.

---

## Pending — Audit blockers

- [x] **HTTPS/TLS** — ACM self-signed import, `:443` listener, 80→443 redirect (`acm.tf`, `load_balancer.tf`)
- [x] **Cognito** — user pool + app client + JWKS JWT enforcement in the gateway (startup patch)
- [x] **Root `README.md`** — architecture, components, setup, configuration, usage, security, monitoring, cost, cleanup
## Pending — Deferred (to do later)

- [x] **`docker/`** — per-service Dockerfiles + `docker-compose.yml` (source in `srcs/`)
- [x] **Microservice source code** — imported from the orchestrator project into `srcs/`
- [x] **Trivy scan evidence** — `monitoring/trivy-scan.txt` (DB images flagged for base upgrade)
- [x] **Billing alerts** — `terraform/budget.tf` (`cloud-design-monthly` budget)
- [x] **Load-test evidence** — `monitoring/load-test.txt` (30,600 requests, 0 errors; scaled 2→3)
- [x] **Rebuilt app images** — `1ee5lim/{api-gateway-app,inventory-app,billing-app}:latest`
  (fixes baked into `srcs/`; the `gateway-patch.py` / `db-pool-patch.py` startup
  overrides were removed from the task definitions)
- [ ] **DB images** — rebuild `oriax11/{inventory-db,billing-db}` on a maintained base
  (e.g. `postgres:15-alpine`) to clear the Debian bookworm backlog

## Pending — HA / scaling

- [x] **Stateless replicas** — api-gateway / inventory-app / billing-app `desired_count = 2` (1/AZ); stateful at 1
- [x] **ECS auto-scaling** — target-tracking 70% CPU, min 2 / max 4 (`autoscaling.tf`)
- [x] **Container Insights** — enabled on the cluster
- [x] **Dashboard completeness** — added ALB target response time, 5XX, and ECS running-task widgets
- [ ] Optional: run a load test to observe a scale-out event

## Pending — Cleanup / correctness

- [ ] **Gateway image rebuild** — remove the `command` workaround (see above).
- [ ] **EFS layout** — `efs.tf` creates 2 file systems (plan: one FS + 2 access points). Works; optional consolidation.
- [ ] **Dead code** — commented EC2/ASG/capacity-provider block in `ecs_cluster.tf` and unused EC2 instance role/profile in `iam.tf`.
- [ ] **Terraform backend** — remote state (optional).

## Notes

- **Billing/queue resilience (Day 14) verified:** scaled billing to 0, sent a valid
  billing payload via the gateway (HTTP 200, queued), scaled billing back to 2,
  and the order row appeared (`user_id=42`). The valid billing schema is
  `{user_id, number_of_items, total_amount}`.
- Cost: leave running only while testing; `terraform destroy` (or scale services to 0)
  when done. See cleanup in `scripts/bootstrap-iam.sh --cleanup`.

---

## Suggested order

1. HTTPS/ACM + Cognito (audit security checks).
2. Replicas + auto-scaling + Container Insights.
3. README + `docker/` + image rebuild.
4. Optional cleanup/consolidation.

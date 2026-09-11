# Architecture Decision Justifications

## Overview

This document justifies every architectural decision made for the Cloud-Design
project, tying each choice to the project requirements, the audit criteria, and
the project constraints (**budget: ~$75 for 15 days**, **timeline: 15 days**,
**simplicity**).

**Fixed decisions:**

- Container orchestration: **AWS ECS on Fargate** (no EC2 instances to manage).
- Container registry: **Docker Hub** (no ECR).
- Databases: **PostgreSQL containers** running as Fargate tasks (no RDS).
- Persistence: **EFS Regional (multi-AZ)** with one access point per database.
- Availability: **2 Availability Zones** with a single NAT Gateway.
- HA model: **Hybrid** — stateless services active-active across AZs; stateful
  services (Postgres, RabbitMQ) single-active.
- HTTPS: **self-signed certificate imported into ACM** (no domain required).
- Authentication: **Amazon Cognito** JWTs enforced at the API gateway.

---

## 1. ECS over EKS

| Decision | ECS on Fargate |
|----------|----------------|
| **Audit requirement** | "Deploy using AWS orchestration tool like ECS or EKS" |
| **Why ECS** | EKS control plane costs $0.10/hr = $36/month, with no budget benefit |
| **Audit impact** | Audit verifies with `aws ecs` commands — fully supported |
| **Learning value** | Teaches AWS-native container orchestration, a skill beyond k3s |
| **Complexity** | No Kubernetes control plane, workers, or add-ons to operate |
| **Tradeoff** | Less portable than Kubernetes, but meets all audit requirements |

**Audit alignment:**
- `aws ecs list-services` shows running services
- `aws ecs describe-services` shows task status
- Load balancing configured via ALB
- `docker ps` is demonstrated locally (see decision 14)

---

## 2. Fargate over EC2

| Decision | ECS Fargate launch type |
|----------|-------------------------|
| **Audit requirement** | "Is the orchestration setup configured correctly?" |
| **Why Fargate** | No EC2 capacity to patch, size, or maintain; serverless compute for containers |
| **Networking win** | Every task uses `awsvpc` mode and gets its own ENI/private IP, so the two `:5432` databases and multiple `:8080` apps no longer collide on host ports |
| **Availability win** | Tasks are scheduled across both AZs automatically |
| **Tradeoff** | Higher per-task cost than EC2 (see cost table), but far simpler and safer |

**Audit alignment:**
- `aws ecs describe-tasks` shows task ENI, IP, and status
- Each service scales independently with ECS Service Auto Scaling
- No EC2 instance management to explain during the role-play

> **Why not EC2?** The previous plan put all six containers on one `t3.micro`
> (1 vCPU / 1 GiB). Two PostgreSQL servers, RabbitMQ, and three Node apps do
> not fit in 1 GiB, and bridge-mode port mapping cannot expose two `5432`s on a
> single host. Fargate removes both problems.

---

## 3. Two Availability Zones with a Hybrid HA Model

| Decision | 2 public + 2 private subnets across 2 AZs |
|----------|-------------------------------------------|
| **Audit requirement** | "Fault-tolerant and maintain high availability, even during component failures" |
| **Why 2 AZs** | ALB, stateless Fargate replicas, and EFS mount targets exist in both AZs, so a single AZ failure does not take the request-serving tier offline |
| **HA model** | **Stateless services active-active across AZs; stateful services single-active** |
| **Budget impact** | Marginal — no extra NAT is added (single NAT is kept, AZ a) |
| **Audit impact** | Demonstrates genuine multi-AZ fault tolerance for the request-serving tier |

**Stateless tier (real HA):**

| Service | Replicas | Behavior on AZ failure |
|---------|----------|------------------------|
| api-gateway-app | 2 (1/AZ) | ALB routes to surviving replica |
| inventory-app | 2 (1/AZ) | Survives |
| billing-app | 2 (1/AZ) | Survives |

**Stateful tier (single-active, documented tradeoff):**

| Service | Active | Standby (AZ b) |
|---------|--------|----------------|
| rabbit-queue | 1 (AZ a) | Box shown for symmetry, **not clustered** |
| inventory-db | 1 (AZ a) | Box shown for symmetry, **not replicated** |
| billing-db | 1 (AZ a) | Box shown for symmetry, **not replicated** |

- **RPO / RTO:** stateful recovery point is the last EFS state; recovery is a
  task relaunch/restore, not an instant promotion.
- **Why not full replication:** real Postgres streaming replication (separate
  EFS access points + `pg_basebackup` + failover) and a RabbitMQ quorum cluster
  add several days of fiddly setup and are not production-recommended on
  EFS/NFS. The hybrid model protects the 15-day timeline and the "simplicity"
  criterion while being explicit about the stateful tier.
- **Future improvement:** RDS Multi-AZ (or Postgres streaming replication with
  per-instance storage) and a RabbitMQ quorum cluster.

**Audit alignment:**
- ALB nodes in both public subnets
- Stateless services spread across both private subnets (active-active)
- EFS Regional mount targets in both private subnets
- Stateful single-active behavior explained honestly in the role-play

---

## 4. Single NAT Gateway (2 AZ design)

| Decision | One NAT Gateway in AZ a |
|----------|-------------------------|
| **Audit requirement** | Private resources must not be publicly reachable |
| **Why single** | A second NAT adds ~$16 for the project window for little audit value |
| **Budget impact** | $0.045/hr ≈ $16.20 for 15 days vs ~$32.40 for two |
| **Audit impact** | Still provides outbound internet (Docker Hub image pulls) for both private subnets |
| **Security** | NAT is outbound-only; no inbound path to private tasks |
| **Tradeoff** | If AZ a fails, new task image pulls and outbound traffic are disrupted. Running tasks, HTTP request handling, and EFS are unaffected. Documented as an accepted tradeoff. |

**Audit alignment:**
- Databases in private subnets (no public IP)
- Fargate tasks in private subnets, outbound via NAT
- VPC isolation maintained

---

## 5. PostgreSQL as Containers (not RDS)

| Decision | PostgreSQL containers as Fargate tasks |
|----------|----------------------------------------|
| **Spec requirement** | "The `inventory-db` **container** is a PostgreSQL database server" |
| **Why containers** | The spec explicitly names all six components, including both databases, as containers |
| **Budget impact** | Saves $24+/month vs two RDS `db.t3.micro` instances |
| **Audit impact** | Meets the spec — all six components are containers |
| **HA posture** | **Single active writer per database** in AZ a; no replication |
| **Tradeoff** | Persistence via EFS (decision 6); no managed failover and no live standby — RTO/RPO are restore-bound (see decision 3) |

**Audit alignment:**
- PostgreSQL on port 5432
- Private subnets only (no public access)
- Security groups restrict access to the ECS task security group
- Data persisted on EFS Regional (multi-AZ)
- Both inventory-app replicas (AZ a + AZ b) read/write the single active DB over Service Connect

---

## 6. EFS Regional (multi-AZ) for Persistence

| Decision | One EFS file system, mount targets in both private subnets, 2 access points |
|----------|------------------------------------------------------------------------------|
| **Problem** | Fargate task storage is ephemeral and lost when a task is replaced |
| **Why EFS** | Only AWS shared filesystem that Fargate tasks can mount natively |
| **Why Regional** | EFS One Zone is ~half the price but lives in a single AZ, contradicting decision 3. At our data size the saving is cents, so Regional multi-AZ is the consistent choice |
| **Why one file system + access points** | Cheaper and simpler than two file systems; access points isolate each DB to its own root directory with POSIX ownership |
| **Configuration** | `/inventory` and `/billing` access points, UID/GID `999` (postgres user), mounted at `/var/lib/postgresql/data` |
| **Writers** | One attachment per access point — a single active DB task per database (no shared writer, no replication) |
| **Cost** | ~$0.30/GB-month → ~$1 for the project window |

**Audit alignment:**
- Data survives task replacement / redeploy
- Mount targets in both AZs match the multi-AZ claim
- No public NFS exposure; security group allows port 2049 only from ECS tasks

---

## 7. ECS Service Connect for Service Discovery

| Decision | Service Connect namespace (`cloud-design.local`) |
|----------|--------------------------------------------------|
| **Problem** | Under Fargate, task IPs change on every deployment, so services cannot hardcode IPs |
| **Why Service Connect** | AWS-native, no extra hop configuration, no additional cost; internal DNS and metrics for service-to-service calls |
| **Alternatives** | AWS Cloud Map (more setup), internal NLB (extra cost), hardcoded IPs (unsustainable) |

**Addressing scheme:**

| Caller | Target | Address |
|--------|--------|---------|
| api-gateway-app | inventory-app | `inventory-app:8080` |
| api-gateway-app | rabbit-queue | `rabbit-queue:5672` |
| billing-app | rabbit-queue | `rabbit-queue:5672` |
| billing-app | billing-db | `billing-db:5432` |
| inventory-app | inventory-db | `inventory-db:5432` |

**Audit alignment:**
- Microservices communicate securely inside the VPC by service name
- No public endpoints for databases or the message queue

---

## 8. ALB with HTTPS (self-signed certificate via ACM)

| Decision | Application Load Balancer, HTTP→HTTPS redirect, self-signed cert imported to ACM |
|----------|-----------------------------------------------------------------------------------|
| **Audit requirement** | "Load balancing configured correctly" and "HTTPS via ACM" |
| **Why ALB** | Native ECS target groups, health checks, path/port routing, TLS termination |
| **Why self-signed** | A publicly trusted ACM certificate requires DNS validation of a domain we do not own. Importing a self-signed certificate still terminates real TLS and is demoed with `curl -k` |
| **Cost** | ALB $0.0225/hr ≈ $8.10 for 15 days + small LCU charges |
| **Security** | TLS termination at the edge; plain HTTP redirected to HTTPS |

**Audit alignment:**
- `aws elbv2 describe-target-health` shows healthy targets
- HTTPS listener returns a valid TLS handshake (self-signed)
- HTTP requests receive a 301 redirect to HTTPS

---

## 9. Cognito for Authentication

| Decision | Amazon Cognito user pool + JWT validation in api-gateway-app |
|----------|---------------------------------------------------------------|
| **Audit requirement** | "Managed authentication using AWS Cognito or similar"; unauthenticated requests rejected |
| **Why Cognito** | Fully managed, free tier (50,000 MAUs), no self-hosting |
| **Why enforce in the gateway** | ALB's Cognito action is session/cookie oriented and redirects browsers. Enforcing the Bearer JWT in `api-gateway-app` gives a clean, testable `401` for API clients, which is exactly what the audit checks |
| **Token flow** | Cognito user pool / app client issues JWTs; gateway verifies signature against the pool JWKS and checks `exp`/`aud` |

**Audit alignment:**
- Request without a valid JWT → `401 Unauthorized`
- Request with a valid Cognito JWT → forwarded normally
- User pool and app client configuration demonstrable in the AWS console / CLI

---

## 10. CloudWatch for Monitoring and Logging

| Decision | CloudWatch Logs + Container Insights + dashboard |
|----------|--------------------------------------------------|
| **Audit requirement** | "Monitoring and logging dashboards providing useful insights" |
| **Why CloudWatch** | Native integration, free tier covers the project, no extra components |
| **Logs** | Every task definition uses the `awslogs` log driver |
| **Metrics** | ECS Container Insights for CPU/memory; ALB request count, latency, 5xx |
| **Tradeoff** | Less customizable than Prometheus/Grafana/ELK, but sufficient and cheaper |

**Audit alignment:**
- Dashboard visible in the AWS console
- Per-service CPU and memory insights
- Centralized logs for all six containers

---

## 11. Docker Hub over ECR

| Decision | Docker Hub public repositories |
|----------|-------------------------------|
| **Audit requirement** | Dockerfiles optimized; deployment verified with `aws cli` |
| **Why Docker Hub** | Free public repositories, no extra setup, images already published |
| **Budget impact** | $0 vs ECR storage ($0.10/GB-month) and data transfer |
| **Tradeoff** | Public images; acceptable for a learning project. Private repos are available if needed |

**Audit alignment:**
- All six images accessible via public URLs
- Fargate tasks pull via the NAT Gateway
- No ECR configuration to explain

---

## 12. Multi-Stage Docker Builds

| Decision | Multi-stage builds on Alpine base images |
|----------|-------------------------------------------|
| **Audit requirement** | "Dockerfiles optimized for efficient container builds" |
| **Why multi-stage** | Reduces final image size by 60–80% by discarding build tooling |
| **Audit impact** | Demonstrated with `docker images` (small sizes) and build timings |
| **Security** | Smaller attack surface and fewer vulnerable packages |

**Audit alignment:**
- `docker images` shows small final images
- Build stage installs dev dependencies; runtime stage copies only artifacts
- No compilers/build tools in production images

---

## 13. Trivy for Vulnerability Scanning

| Decision | Trivy image scanning in the local build pipeline |
|----------|--------------------------------------------------|
| **Audit requirement** | "Regularly scanning for vulnerabilities" |
| **Why Trivy** | Free, open-source, scans images before they are pushed |
| **Why not Inspector** | Amazon Inspector only scans ECR images (we use Docker Hub). Inspector runtime monitoring for ECS/Fargate is an optional add-on |
| **Where** | `scripts/scan.sh` runs `trivy image --severity HIGH,CRITICAL` after each build |

**Audit alignment:**
- Scan output shown for each of the six images
- Critical/high findings documented and remediated (base image bumps)

---

## 14. Docker Compose for Local Parity

| Decision | `docker/docker-compose.yml` for local development |
|----------|----------------------------------------------------|
| **Audit requirement** | Verify deployment ("`docker ps` if applicable") |
| **Why Compose** | Fargate has no user-accessible Docker daemon on the host, so `docker ps` applies to local development only |
| **Audit impact** | Auditor sees `docker compose ps` locally and `aws ecs describe-tasks` for the cloud deployment |
| **Value** | Fast iteration and functional testing before pushing to Docker Hub |

**Audit alignment:**
- Local `docker compose ps` shows all six containers
- Cloud deployment verified with `aws ecs` commands

---

## Audit Compliance Matrix

| Audit Criterion | Implementation | Cost | Justification |
|-----------------|----------------|------|---------------|
| Repository files | README.md, docker/, terraform/, ecs/, scripts/ | $0 | Required for submission |
| Role-play (14 Qs) | Study + practice | $0 | Demonstrates understanding |
| Architecture design (5 criteria) | Documented in README | $0 | Scalability, availability, security, cost, simplicity |
| README completeness | Diagrams, setup, config, usage | $0 | Required documentation |
| Deployment verification | `aws ecs`, local `docker compose ps` | $0 | Shows working deployment |
| API Gateway POST/GET | api-gateway → inventory-app | $0 | Core functionality (movies) |
| Billing resilience | RabbitMQ queues messages while billing-app is stopped | $0 | Demonstrates async processing |
| Terraform | All infra in code | $0 | IaC requirement |
| Optimized Dockerfiles | Multi-stage builds | $0 | Reduces image size |
| Monitoring dashboards | CloudWatch Container Insights + dashboard | $0 | Free tier, sufficient |
| Auto-scaling | ECS Service Auto Scaling (apps min 2 / max 4) | included | Handles varying workloads |
| Availability | Hybrid HA: stateless active-active across 2 AZs; stateful single-active (documented) | included | Fault tolerance for request tier |
| Security: HTTPS | Self-signed cert imported to ACM + ALB | $0 | Real TLS enabled |
| Security: Cognito | User pool + JWT → `401` | $0 | Free tier (50K MAUs) |
| Security: VPC | Private subnets, no public IPs | $0 | Isolation requirement |
| Security: scanning | Trivy pre-push | $0 | Vulnerability scanning |
| Container registry | Docker Hub | $0 | Free public repos |

---

## Cost Optimization Summary

| Optimization | 15-Day Saving | Impact |
|--------------|---------------|--------|
| ECS over EKS | ~$18 | No control plane cost |
| Right-sized Fargate tasks | — | Minimal vCPU/memory per task |
| Hybrid HA instead of full replication | ~$26 | No extra DB/queue replication tasks |
| Single NAT Gateway | ~$16 | One gateway sufficient |
| Single EFS + 2 access points | ~$0.15 | One file system instead of two |
| Docker Hub over ECR | ~$0.10 | Free public repos |
| CloudWatch free tier | ~$5–10 | No monitoring cost |
| **Total** | **~$40+** | Well within budget |

> **Fargate vs EC2 note:** Fargate costs more than a single `t3.micro`, but the
> EC2 option cannot actually run nine tasks in 1 GiB of memory. The comparison
> is Fargate against a realistically sized EC2 setup (t3.medium × 2, ~$30 for
> 15 days) plus the operational overhead — not against an under-sized
> `t3.micro`.

---

## Learning Value

| Decision | What You Learn |
|----------|----------------|
| ECS Fargate | Container orchestration, task definitions, service autoscaling |
| `awsvpc` networking | Task-level ENIs, security groups, Service Connect DNS |
| EFS | Shared persistent storage for containers, POSIX access points |
| Hybrid HA | Active-active stateless replicas vs single-active stateful services, and the RTO/RPO tradeoff |
| ALB + ACM | TLS termination, target groups, health checks |
| Cognito | JWT issuance/verification, API authorization |
| CloudWatch | Logs, metrics, dashboards for containers |
| Trivy | Image vulnerability scanning in a build pipeline |

---

## Conclusion

This architecture is **appropriate for the given constraints**:

- **Budget:** ~$71 for 15 days (ceiling ~$75)
- **Time:** Achievable in 15 days
- **Audit:** All repository, architecture, deployment, functionality, IaC,
  monitoring, scaling, and security criteria addressed
- **Availability:** Hybrid HA — stateless services active-active across 2 AZs;
  stateful services single-active with a documented tradeoff
- **Security:** 2-AZ network isolation, TLS, Cognito JWT auth, EFS-encrypted
  persistent storage, image scanning
- **Simplicity:** Managed Fargate compute, Docker Hub, one EFS, one NAT, a
  single discovered service namespace

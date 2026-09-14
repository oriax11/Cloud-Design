# Role-Play Preparation

Model answers for the 14 stakeholder questions in `docs/cloud-design-audit.md`,
grounded in the actual implementation. Use these as speaking notes, not a script.

---

### 1. What is the cloud and its associated benefits?

The cloud is on-demand access to computing, storage and networking resources
that someone else operates, paid for by usage. Key benefits: no upfront
hardware, elasticity (scale up/down in minutes), pay-as-you-go, global
availability, managed services that offload patching and durability, and
built-in security/compliance tooling.

### 2. Why is deploying the solution in the cloud preferred over on-premises?

- **Speed:** infrastructure is provisioned in minutes via Terraform instead of
  weeks of procurement.
- **Cost:** no capex; we pay only for what runs, and can destroy everything.
- **Elasticity:** auto-scaling handles variable traffic; on-prem would need
  capacity sized for peak.
- **Availability:** multiple AZs give fault tolerance without a second data
  centre.
- **Managed services:** ECS/Fargate, EFS, ALB, Cognito, Secrets Manager remove
  undifferentiated operational work.
- **Security:** IAM, VPC isolation, ACM and managed auth are built in.

### 3. How would you differentiate between public, private, and hybrid cloud?

- **Public:** shared provider infrastructure, multi-tenant (what we use — AWS).
- **Private:** dedicated to one organisation, on-prem or hosted.
- **Hybrid:** a mix, with workloads split and connected (e.g. sensitive data
  on-prem, bursty frontends in the cloud).
Our design is public cloud, but we *emulate* a private network boundary with a
VPC and private subnets.

### 4. What drove your decision to select AWS for this project, and what factors did you consider?

- Breadth of managed services (ECS/Fargate, EFS, ALB, Cognito, Secrets Manager).
- Mature Terraform provider, so everything is reproducible as code.
- Familiar tooling (`aws` CLI) and strong docs/free tiers.
- Region choice: `us-east-1` for the widest service availability and lowest cost.
- Cost: no Kubernetes control plane (we chose ECS over EKS to save $36/month).

### 5. Can you describe your microservices application's AWS-based architecture and the interaction between its components?

**Ingress:** users hit an internet-facing **ALB** over HTTPS (`:443`, ACM
self-signed cert; `:80` redirects). The ALB forwards to **api-gateway-app**
(Fargate, `:3000`) in the private subnets.

**Gateway:** validates the **Cognito** JWT on `/api/*`, then proxies
`/api/movies` to **inventory-app** (`:8080`) and publishes billing requests to
**rabbit-queue** (`:5672`).

**Services:** **inventory-app** reads/writes **inventory-db** (`:5432`);
**billing-app** consumes the queue and writes **billing-db** (`:5432`).
PostgreSQL data is persisted on **EFS** (one access point per DB).

**Networking:** 2 AZs, public subnets for the ALB, private subnets for all
tasks, a single NAT for outbound, security groups between tiers, and **ECS
Service Connect** for service-to-service DNS.

### 6. How did you manage and optimize the cost of your AWS solution?

- **ECS over EKS** (no $0.10/hr control plane).
- **Fargate right-sized** at 0.25 vCPU (apps 0.5 GB; DB/Rabbit 1 GB).
- **Single NAT Gateway** instead of two.
- **One EFS** with access points, Docker Hub instead of ECR, CloudWatch free tier.
- **Autoscaling** min 2 / max 4 keeps capacity near demand.
- **AWS Budget** `cloud-design-monthly` with 50/80/100% email alerts.
- Total ≈ **$70 for 15 days**; `terraform destroy` tears it all down.

### 7. What measures did you implement to ensure application security on AWS, and what AWS security best practices did you adhere to?

- **Network:** private subnets, no public IPs on tasks, DBs reachable only from
  the VPC, least-privilege security groups, outbound-only NAT.
- **Identity:** Cognito user pool; RS256 JWT verified against the pool JWKS on
  every `/api/*` request (`401` otherwise).
- **Transport:** TLS at the ALB (ACM); Service Connect inside the VPC.
- **Secrets:** all credentials in Secrets Manager, injected as task secrets
  (never baked into images).
- **Least privilege IAM:** separate execution/task roles; scoped policies.
- **Scanning:** Trivy image scans recorded in `monitoring/trivy-scan.txt`.
- **Encryption at rest:** EFS encrypted.

### 8. What AWS monitoring and logging tools did you utilize, and how did they assist in identifying and troubleshooting application issues?

- **CloudWatch Logs** (one group per service, `awslogs` driver) — this is how we
  diagnosed the gateway `hop-by-hop` 500s and the inventory `SSL SYSCALL error:
  EOF detected` (stale DB connections).
- **Container Insights** for per-service CPU/memory.
- A **CloudWatch dashboard** with CPU/memory, ALB request count, target
  response time, 5XX, and running-task counts.
- CloudWatch metrics confirmed the CPU spike (85–95%) that triggered autoscaling.

### 9. Can you describe the AWS auto-scaling policies you implemented and how they help your application accommodate varying workloads?

- **ECS Service Auto Scaling**, target-tracking on **average CPU at 70%**.
- Applies to the stateless services (api-gateway, inventory-app, billing-app),
  **min 2 (one per AZ) / max 4**; stateful services stay at 1.
- Under a sustained load test the gateway scaled **2 → 3** automatically.
- Scaling is spread across both AZs; scale-in cool-down avoids flapping.

### 10. How did you optimize Docker images for each microservice, and how did this impact build times, image sizes?

- **`python:3.12-alpine`** base → small images (~72–100 MB) and fast pulls.
- `requirements.txt` copied and installed **before** the source, so dependency
  layers cache and rebuilds only re-run on code changes.
- `pip install --no-cache-dir` keeps layers small.
- Docker Hub stores the images; Fargate pulls them via NAT.
- Future: multi-stage builds if we add build-time tooling.

### 11. If you had to redo this project, what modifications would you make to your approach or the technologies you used?

- Put the microservice **source in this repo from day one** (we imported it
  later) and rebuild images from it.
- Add the **Cognito auth and DB connection fixes in the images** from the start
  instead of runtime patches.
- Use **RDS Multi-AZ** (or Postgres streaming replication) for real stateful
  HA, and a **RabbitMQ cluster**.
- Add **CI** (build/scan/push) and run **Trivy from the first commit**.
- Rebuild the DB images on a maintained base (Alpine) to avoid the Debian backlog.

### 12. How can your AWS solution be expanded or altered to cater to future requirements like adding new microservices or migrating to a different cloud provider?

- **New service:** add a task definition + ECS service and register it in the
  Service Connect namespace — the gateway routes by path. No VPC changes.
- **Scale data tier:** move Postgres to RDS Multi-AZ; cluster RabbitMQ.
- **Portability:** everything is Terraform; container images and 12-factor env
  config are cloud-agnostic. ECS would map to GKE/Cloud Run or AKS; the ALB to
  a cloud LB. Stateful data would migrate via dump/restore or DMS.

### 13. What challenges did you face during the project and how did you address them?

- **Gateway 500s on some requests:** the image forwarded the hop-by-hop
  `Connection` header, which waitress rejects. Fixed in the source (return no
  upstream headers) and rebuilt.
- **Intermittent 500s on inventory:** idle DB connections were dropped through
  Service Connect (`SSL SYSCALL error: EOF detected`). Fixed with SQLAlchemy
  `pool_pre_ping`/`pool_recycle`.
- **ALB health check failing:** default `/` returned 404; added a `/` route and
  pointed the health check at it.
- **Second Postgres writer risk:** kept DBs single-active and documented the
  RTO/RPO tradeoff rather than corrupting the shared EFS data dir.
- **Missing source/Dockerfiles:** imported them from the orchestrator project.

### 14. How did you ensure your documentation's clarity and completeness, and what measures did you take to make it easily understandable and maintainable?

- One **`README.md`** with architecture diagram, component table, prerequisites,
  configuration, deploy steps, usage examples, security, monitoring, cost and
  cleanup.
- **`docs/`** keeps the subject, audit, architecture plan/justification, the
  audit checklist and this role-play prep.
- Diagrams are **Mermaid** (versioned as text) with a colour legend.
- Everything is **code**: Terraform modules, exported task definitions,
  dashboard JSON, scan/load-test evidence.
- A **task tracker** (`docs/terraform-task-tracking.md`) records what is done
  and what remains.

---

## Quick live demo checklist

1. `cd terraform && terraform plan` → No changes.
2. `aws ecs list-services --cluster cloud-design-cluster`
3. `aws ecs describe-services ...` (show 2/2 replicas)
4. `curl -k https://<alb>/` → 200
5. `curl -k https://<alb>/api/movies` → 401
6. `./scripts/create-test-user.sh` → token (pool/client auto-discovered)
7. `curl -k -H "Authorization: Bearer <token>" https://<alb>/api/movies` → 200
8. `POST /api/movies` → 201; `POST /api/billing/` → 200
9. Billing resilience: scale billing to 0, send billing, scale back, show the row.
10. `aws elbv2 describe-target-health` and the CloudWatch dashboard.

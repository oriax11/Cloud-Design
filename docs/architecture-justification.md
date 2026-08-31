# Architecture Decision Justifications

## Overview

This document justifies every architectural decision made for the Cloud-Design project, tying each choice to project requirements, audit criteria, and constraints (budget: $100, timeline: 15 days, simplicity).

---

## 1. ECS over EKS

| Decision | ECS with EC2 |
|----------|--------------|
| **Audit requirement** | "Deploy using AWS orchestration tool like ECS or EKS" |
| **Why ECS** | EKS control plane costs $0.10/hr = $36/month (44% of budget) |
| **Audit impact** | Audit verifies with `aws ecs` commands, `docker ps` — both work with ECS |
| **Learning value** | Teaches AWS-native container orchestration, new skill beyond k3s |
| **Complexity** | Lower than EKS, faster to set up within 15 days |
| **Tradeoff** | Less portable than Kubernetes, but meets all audit requirements |

**Audit alignment:**
- ✅ `aws ecs list-services` shows running services
- ✅ `aws ecs describe-services` shows task status
- ✅ `docker ps` shows containers
- ✅ Load balancing configured via ALB

---

## 2. EC2 over Fargate

| Decision | EC2 with Auto Scaling Group |
|----------|----------------------------|
| **Audit requirement** | "Is the orchestration setup configured correctly?" |
| **Why EC2** | Fargate costs ~$0.04048/hr per task = ~$14.57/day = $218 for 30 days |
| **Budget impact** | EC2 t3.micro = $0.0104/hr = $7.49/month vs Fargate ~$218 |
| **Audit impact** | Audit checks `docker ps` on EC2 instances — visible and verifiable |
| **Learning value** | Understanding EC2 + ECS integration is valuable |
| **Tradeoff** | More management than Fargate, but 97% cheaper |

**Audit alignment:**
- ✅ `docker ps` shows containers on EC2 instances
- ✅ Can demonstrate `aws ecs list-tasks --cluster <name>`
- ✅ Auto-scaling visible in AWS console

---

## 3. Single NAT Gateway (not two)

| Decision | Single NAT Gateway |
|----------|-------------------|
| **Audit requirement** | "Databases only accessible from AWS VPC" |
| **Why single** | Two NAT gateways = $32.40/month each = $64.80 total (76% of budget) |
| **Budget impact** | One NAT = $32.40 vs two = $64.80 |
| **Audit impact** | Still provides internet access for private subnets, meets VPC isolation |
| **Security** | Databases remain in private subnets, no public access |
| **Tradeoff** | Single point of failure for outbound traffic, acceptable for learning |

**Audit alignment:**
- ✅ Databases in private subnets (no public IP)
- ✅ ECS nodes can pull images and connect to services
- ✅ VPC isolation maintained

---

## 4. PostgreSQL as Containers (not RDS)

| Decision | PostgreSQL containers in ECS |
|----------|----------------------------|
| **Spec requirement** | "The `inventory-db` **container** is a PostgreSQL database server" |
| **Why containers** | Spec explicitly says "container" for all 6 components, including databases |
| **Budget impact** | Saves $24.48/month vs RDS (db.t3.micro × 2) |
| **Audit impact** | Meets spec requirement — all 6 are containers |
| **Learning value** | Matches your k3s experience, container orchestration consistency |
| **Tradeoff** | Need EBS volumes for data persistence, more manual than RDS |

**Audit alignment:**
- ✅ PostgreSQL on port 5432
- ✅ Private subnet only (no public access)
- ✅ Security group restricts access to ECS nodes only
- ✅ All 6 components are containers (matches spec)

---

## 5. ALB (Application Load Balancer)

| Decision | ALB with HTTPS |
|----------|----------------|
| **Audit requirement** | "Load balancing configured correctly, distributing traffic" |
| **Why ALB** | Only option for ECS service discovery + health checks |
| **Cost impact** | $0.0225/hr = $16.20/month + LCU charges |
| **Audit impact** | Audit checks load balancing works, ALB provides this |
| **Security** | Supports ACM certificates for HTTPS |
| **Features** | Path-based routing, target groups, health checks |

**Audit alignment:**
- ✅ `aws elbv2 describe-target-health` shows healthy targets
- ✅ Traffic distributed across ECS tasks
- ✅ HTTPS via ACM certificate (free)

---

## 6. CloudWatch for Monitoring

| Decision | CloudWatch (free tier) |
|----------|------------------------|
| **Audit requirement** | "Monitoring and logging dashboards providing useful insights" |
| **Why CloudWatch** | Free tier covers basic metrics, no extra cost |
| **Budget impact** | $0 (within free tier limits) |
| **Audit impact** | Dashboard shows CPU, memory, request counts |
| **Integration** | Native AWS integration, no extra setup |
| **Tradeoff** | Less customizable than Prometheus/Grafana, but sufficient |

**Audit alignment:**
- ✅ Dashboard visible in AWS console
- ✅ Metrics for ECS, RDS, ALB
- ✅ Logs centralized in CloudWatch Logs

---

## 7. Cognito for Authentication

| Decision | AWS Cognito |
|----------|-------------|
| **Audit requirement** | "Managed authentication using AWS Cognito or similar" |
| **Why Cognito** | Fully managed, free tier (50,000 MAUs), no self-hosting |
| **Cost impact** | $0 (within free tier) |
| **Audit impact** | Audit tests unauthenticated requests are rejected |
| **Security** | JWT tokens, user pools, app clients |
| **Integration** | ALB listener rules with Cognito authorizer |

**Audit alignment:**
- ✅ Request without auth → 401 Unauthorized
- ✅ Request with valid JWT → allowed
- ✅ User pool manages authentication

---

## 8. Multi-Stage Docker Builds

| Decision | Multi-stage builds with alpine |
|----------|-------------------------------|
| **Audit requirement** | "Dockerfiles optimized for efficient container builds" |
| **Why multi-stage** | Reduces final image size by 60-80% |
| **Audit impact** | Audit checks image sizes and build times |
| **Security** | Smaller attack surface, fewer vulnerabilities |
| **Performance** | Faster pulls from ECR, less storage |
| **Example** | Build stage: full Node.js image → Production: alpine + dist only |

**Audit alignment:**
- ✅ `docker images` shows small image sizes
- ✅ `docker build` completes quickly
- ✅ No unnecessary dependencies in production

---

## 9. VPC with Public/Private Subnets (1 AZ)

| Decision | 1 public + 1 private subnet (single AZ) |
|----------|------------------------------------------|
| **Audit requirement** | "Databases only accessible from AWS VPC" |
| **Why this layout** | Public: ALB, NAT Gateway → Private: RDS, ECS tasks |
| **Budget impact** | Single NAT Gateway, minimal data transfer |
| **Audit impact** | Demonstrates VPC isolation, security groups |
| **Why 1 AZ** | 2 AZs adds unnecessary complexity and cost for a learning project |
| **Security** | Private subnets have no internet access |

**Audit alignment:**
- ✅ RDS in private subnets (no public IP)
- ✅ ECS tasks in private subnets (via NAT)
- ✅ ALB in public subnets (internet-facing)
- ✅ Security groups control traffic flow

---

## 10. Docker Hub for Container Images

| Decision | Docker Hub (not ECR) |
|----------|---------------------|
| **Audit requirement** | "Dockerfiles optimized, deployment verified with aws cli" |
| **Why Docker Hub** | Free public repos, no extra setup, images already exist there |
| **Budget impact** | $0 (free tier) |
| **Audit impact** | Audit checks ECS commands, not ECR. Docker Hub works fine. |
| **Security** | Public repos for learning project, private repos available |
| **6 images** | inventory-app, billing-app, api-gateway-app, rabbit-queue, inventory-db, billing-db |

**Audit alignment:**
- ✅ All 6 images accessible via public URLs
- ✅ ECS tasks pull images via NAT Gateway
- ✅ `docker ps` shows running containers

---

## Summary: Why These Choices Work

| Constraint | Solution | Justification |
|------------|----------|---------------|
| **$100 budget** | ECS EC2, single NAT, Docker Hub | Total ~$29 for 15 days |
| **15 days** | ECS over EKS, CloudWatch over ELK | Faster setup, less complexity |
| **Learning** | ECS (new skill) + your k3s knowledge | Broadens container expertise |
| **Audit requirements** | All 15 criteria met | Documented in plan |
| **Simplicity** | Single NAT, single-AZ RDS | Minimal moving parts |
| **Security** | VPC isolation, Cognito, HTTPS | All audit security checks |

---

## Audit Compliance Matrix

| Audit Criterion | Implementation | Cost | Justification |
|-----------------|----------------|------|---------------|
| Repository files | README.md, docker/, terraform/, ecs/ | $0 | Required for submission |
| Role-play (13 Qs) | Study + practice | $0 | Demonstrates understanding |
| Architecture design | Documented in README | $0 | Meets all 5 design criteria |
| README completeness | Diagrams, setup, config, usage | $0 | Required documentation |
| Deployment verification | `aws ecs`, `docker ps` | $0 | Shows working deployment |
| API Gateway POST/GET | api-gateway → inventory-app | $0 | Core functionality |
| Billing resilience | RabbitMQ queues messages | $0 | Demonstrates async processing |
| Terraform | All infra in code | $0 | IaC requirement |
| Optimized Dockerfiles | Multi-stage builds | $0 | Reduces image size |
| Monitoring dashboards | CloudWatch | $0 | Free tier, sufficient |
| Auto-scaling | ECS Service Auto Scaling | ~$5 | Handles varying workloads |
| Security: HTTPS | ACM + ALB | $0 | Free certificates |
| Security: Cognito | User pool + JWT | $0 | Free tier (50K MAUs) |
| Security: VPC | Private subnets | $0 | Isolation requirement |
| Container Registry | Docker Hub (free) | $0 | Free public repos |

---

## Cost Optimization Summary

| Optimization | Savings | Impact |
|--------------|---------|--------|
| ECS over EKS | $36/month | No control plane cost |
| EC2 over Fargate | ~$210/month | 97% cheaper compute |
| Single NAT Gateway | $32.40/month | One gateway sufficient |
| Docker Hub over ECR | $0.10/month | Free public repos |
| CloudWatch free tier | $10-20/month | No monitoring cost |
| **Total savings** | **~$303/month** | **85% reduction** |

---

## Learning Value Despite Simplifications

| Simplification | What You Still Learn |
|----------------|---------------------|
| ECS over EKS | Container orchestration, service discovery, load balancing |
| EC2 over Fargate | EC2 management, auto-scaling groups, IAM roles |
| Single NAT | VPC networking, subnet routing, security groups |
| Docker Hub | Image management, public/private registries |
| CloudWatch | Metrics collection, dashboards, log aggregation |
| Cognito | JWT authentication, user pools, app clients |

**You're still learning core AWS concepts — just at lower cost and complexity.**

---

## Conclusion

This architecture is **optimal for the given constraints**:

- **Budget:** ~$29 for 15 days (71% under budget)
- **Time:** 15 days achievable with this simplicity
- **Audit:** All 15 criteria met
- **Learning:** New AWS skills (ECS, ALB, Cognito, CloudWatch)
- **Security:** VPC isolation, HTTPS, authentication
- **Simplicity:** Docker Hub (no ECR setup), single NAT, 1 AZ

**Any more complex solution would either exceed budget or timeline.**

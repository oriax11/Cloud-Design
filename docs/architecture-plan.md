# Cloud-Design Architecture Plan

## Overview

This document outlines the detailed 15-day implementation plan for the Cloud-Design project, aligned with both the project specification and audit requirements.

---

## Budget Breakdown (15 Days)

| Resource | Instance | Hourly Rate | 15 Days (360h) | Total |
|----------|----------|-------------|-----------------|-------|
| ECS EC2 | t3.micro | $0.0104 | $3.75 | **$3.75** |
| ALB | - | $0.0225 | $8.10 | **$9.00** |
| NAT Gateway | - | $0.045 | $16.20 | **$16.20** |
| CloudWatch | Free tier | $0 | $0 | **$0** |
| Docker Hub | Free tier | $0 | $0 | **$0** |
| **Total** | | | | **~$28.95** |
| **Remaining** | | | | **~$71.05** |

> **Note:** All 6 containers (including databases) run as Docker images in ECS.
> Images stored on Docker Hub (free public repos). No RDS — databases run as PostgreSQL containers with EBS volumes for persistence.

---

## Architecture Diagram (1 AZ - 6 Containers)

```mermaid
flowchart TB
    subgraph Internet
        User[User/Client]
        DockerHub[Docker Hub<br/>6 Public Images]
    end

    subgraph AWS_Cloud["AWS Cloud"]
        subgraph Public_Subnet["Public Subnet (10.0.1.0/24)"]
            ALB[ALB<br/>:80/:443]
            NAT[NAT Gateway]
        end

        subgraph Private_Subnet["Private Subnet (10.0.2.0/24)"]
            subgraph ECS["ECS Cluster (t3.micro)"]
                GW[api-gateway-app<br/>:3000]
                INV[inventory-app<br/>:8080]
                BILL[billing-app<br/>:8080]
                RABBIT[RabbitMQ<br/>:5672]
                INV_DB[(inventory-db<br/>PostgreSQL:5432)]
                BILL_DB[(billing-db<br/>PostgreSQL:5432)]
            end
        end
    end

    subgraph AWS_Services["AWS Services"]
        CW[CloudWatch<br/>Metrics + Logs]
        COGNITO[Cognito<br/>JWT Auth]
    end

    User -->|HTTPS| ALB
    ALB --> GW
    GW -->|inventory request| INV
    GW -->|billing request| RABBIT
    RABBIT -->|consume message| BILL
    BILL -->|write billing| BILL_DB
    INV -->|write inventory| INV_DB

    DockerHub -.->|pull via NAT| NAT
    NAT -.->|internet| ECS

    CW -.-> ECS
    CW -.-> ALB
    COGNITO -.-> ALB

    style Internet fill:#1a1a2e,stroke:#e94560,color:#ffffff
    style AWS_Cloud fill:#16213e,stroke:#0f3460,color:#ffffff
    style Public_Subnet fill:#0f3460,stroke:#533483,color:#ffffff
    style Private_Subnet fill:#0f3460,stroke:#533483,color:#ffffff
    style ECS fill:#1a1a2e,stroke:#e94560,color:#ffffff
    style AWS_Services fill:#1a1a2e,stroke:#e94560,color:#ffffff
    style User fill:#e94560,stroke:#ffffff,color:#ffffff
    style DockerHub fill:#2496ED,stroke:#ffffff,color:#ffffff
    style ALB fill:#533483,stroke:#e94560,color:#ffffff
    style NAT fill:#533483,stroke:#e94560,color:#ffffff
    style GW fill:#0f3460,stroke:#e94560,color:#ffffff
    style INV fill:#0f3460,stroke:#e94560,color:#ffffff
    style BILL fill:#0f3460,stroke:#e94560,color:#ffffff
    style RABBIT fill:#e94560,stroke:#ffffff,color:#ffffff
    style INV_DB fill:#533483,stroke:#e94560,color:#ffffff
    style BILL_DB fill:#533483,stroke:#e94560,color:#ffffff
    style CW fill:#0f3460,stroke:#533483,color:#ffffff
    style COGNITO fill:#0f3460,stroke:#533483,color:#ffffff
```

### Data Flow

```
1. User → ALB (443/HTTPS) → api-gateway (3000)
2. api-gateway → inventory-app (8080) [inventory operations]
3. api-gateway → RabbitMQ (5672) [billing request]
4. RabbitMQ → billing-app (8080) [consumer processes message]
5. billing-app → billing-db (5432) [write billing record]
6. inventory-app → inventory-db (5432) [write inventory]
7. NAT Gateway → internet access for private subnet (pull from ECR)
```

### Container Inventory

| Container | Image | Port | Description |
|-----------|-------|------|-------------|
| api-gateway-app | username/api-gateway-app | 3000 | Routes requests to services |
| inventory-app | username/inventory-app | 8080 | Handles inventory operations |
| billing-app | username/billing-app | 8080 | Processes billing via RabbitMQ |
| rabbit-queue | rabbitmq:3-management | 5672 | Message queue for async |
| inventory-db | postgres:15-alpine | 5432 | PostgreSQL inventory data |
| billing-db | postgres:15-alpine | 5432 | PostgreSQL billing data |

> Replace `username` with your Docker Hub username in all task definitions.

---

## Docker Hub Flow Diagram

```mermaid
flowchart LR
    subgraph Local["Local Machine"]
        BUILD[docker build]
        PUSH[docker push]
    end

    subgraph DockerHub["Docker Hub (Public)"]
        R1[username/inventory-app]
        R2[username/billing-app]
        R3[username/api-gateway-app]
        R4[rabbitmq:3-management]
        R5[postgres:15-alpine]
    end

    subgraph ECS["ECS Cluster"]
        AGENT[ECS Agent]
    end

    BUILD -->|images| PUSH
    PUSH -->|upload| DockerHub
    AGENT -->|pull via NAT| DockerHub

    style Local fill:#1a1a2e,stroke:#e94560,color:#ffffff
    style DockerHub fill:#2496ED,stroke:#ffffff,color:#ffffff
    style ECS fill:#16213e,stroke:#0f3460,color:#ffffff
    style BUILD fill:#e94560,stroke:#ffffff,color:#ffffff
    style PUSH fill:#533483,stroke:#e94560,color:#ffffff
    style R1 fill:#ffffff,stroke:#2496ED,color:#000000
    style R2 fill:#ffffff,stroke:#2496ED,color:#000000
    style R3 fill:#ffffff,stroke:#2496ED,color:#000000
    style R4 fill:#ffffff,stroke:#2496ED,color:#000000
    style R5 fill:#ffffff,stroke:#2496ED,color:#000000
    style AGENT fill:#e94560,stroke:#ffffff,color:#ffffff
```

---

## ECS Cluster Diagram

```mermaid
flowchart TB
    subgraph AWS_Cloud["AWS Cloud"]
        subgraph Public_Subnet["Public Subnet (10.0.1.0/24)"]
            ALB[ALB<br/>:80/:443]
            NAT[NAT Gateway]
        end

        subgraph Private_Subnet["Private Subnet (10.0.2.0/24)"]
            subgraph ECS["ECS Cluster"]
                subgraph EC2["EC2 Instance (t3.micro)"]
                    AGENT[ECS Agent]
                    subgraph Tasks["Running Tasks"]
                        T1[api-gateway-app<br/>:3000]
                        T2[inventory-app<br/>:8080]
                        T3[billing-app<br/>:8080]
                        T4[RabbitMQ<br/>:5672]
                        T5[inventory-db<br/>:5432]
                        T6[billing-db<br/>:5432]
                    end
                end
            end
        end
    end

    subgraph DockerHub["Docker Hub"]
        DH[Public Images]
    end

    AGENT -->|manages| Tasks
    DH -.->|pull via NAT| NAT
    NAT -.->|internet| AGENT
    ALB -->|routes| T1
    T1 -->|inventory| T2
    T1 -->|billing| T4
    T4 -->|consume| T3
    T3 -->|write| T6
    T2 -->|write| T5

    style AWS_Cloud fill:#16213e,stroke:#0f3460,color:#ffffff
    style Public_Subnet fill:#0f3460,stroke:#533483,color:#ffffff
    style Private_Subnet fill:#0f3460,stroke:#533483,color:#ffffff
    style ECS fill:#1a1a2e,stroke:#e94560,color:#ffffff
    style EC2 fill:#16213e,stroke:#0f3460,color:#ffffff
    style Tasks fill:#0f3460,stroke:#533483,color:#ffffff
    style DockerHub fill:#2496ED,stroke:#ffffff,color:#ffffff
    style ALB fill:#533483,stroke:#e94560,color:#ffffff
    style NAT fill:#533483,stroke:#e94560,color:#ffffff
    style AGENT fill:#e94560,stroke:#ffffff,color:#ffffff
    style T1 fill:#0f3460,stroke:#e94560,color:#ffffff
    style T2 fill:#0f3460,stroke:#e94560,color:#ffffff
    style T3 fill:#0f3460,stroke:#e94560,color:#ffffff
    style T4 fill:#e94560,stroke:#ffffff,color:#ffffff
    style T5 fill:#533483,stroke:#e94560,color:#ffffff
    style T6 fill:#533483,stroke:#e94560,color:#ffffff
    style DH fill:#ffffff,stroke:#2496ED,color:#000000
```

---

## VPC Networking Diagram

```mermaid
flowchart TB
    subgraph VPC["VPC (10.0.0.0/16)"]
        subgraph Public_Subnet["Public Subnet (10.0.1.0/24)"]
            IGW[Internet Gateway]
            ALB[ALB<br/>10.0.1.10<br/>:80/:443]
            NAT[NAT Gateway<br/>10.0.1.100]
            PUB_RT["Route Table<br/>10.0.0.0/16 → local<br/>0.0.0.0/0 → IGW"]
        end

        subgraph Private_Subnet["Private Subnet (10.0.2.0/24)"]
            ECS_Container[ECS Cluster<br/>10.0.2.10]
            PRIV_RT["Route Table<br/>10.0.0.0/16 → local<br/>0.0.0.0/0 → NAT"]
        end
    end

    Internet((Internet))

    Internet -->|Public IP| IGW
    IGW --> ALB
    ALB -->|VPC local: 10.0.1.x → 10.0.2.x| ECS_Container
    ECS_Container -->|VPC local: 10.0.2.x → 10.0.1.100| NAT
    NAT -->|Public IP| IGW
    IGW --> Internet

    PUB_RT -.->|routes traffic| ALB
    PUB_RT -.->|routes traffic| NAT
    PRIV_RT -.->|routes traffic| ECS_Container
    PRIV_RT -.->|default route via NAT| NAT

    style VPC fill:#16213e,stroke:#0f3460,color:#ffffff
    style Public_Subnet fill:#0f3460,stroke:#533483,color:#ffffff
    style Private_Subnet fill:#0f3460,stroke:#533483,color:#ffffff
    style IGW fill:#e94560,stroke:#ffffff,color:#ffffff
    style ALB fill:#533483,stroke:#e94560,color:#ffffff
    style NAT fill:#e94560,stroke:#ffffff,color:#ffffff
    style ECS_Container fill:#1a1a2e,stroke:#e94560,color:#ffffff
    style PUB_RT fill:#16213e,stroke:#533483,color:#ffffff
    style PRIV_RT fill:#16213e,stroke:#533483,color:#ffffff
    style Internet fill:#ffffff,stroke:#e94560,color:#000000
```

### How Subnets Link

| Path | Route | Example |
|------|-------|---------|
| **Public ↔ Private** | VPC local route (10.0.0.0/16) | ALB (10.0.1.10) → ECS (10.0.2.10) |
| **Private → Internet** | 0.0.0.0/0 → NAT Gateway | ECS pulls from Docker Hub |
| **Internet → Public** | 0.0.0.0/0 → Internet Gateway | User accesses ALB |
| **Container ↔ Container** | VPC local route (same subnet) | ECS → ECS (10.0.2.x ↔ 10.0.2.x) |

### Key Security Points

- **Private subnet has no public IPs** — containers cannot be accessed from internet
- **NAT Gateway only allows outbound** — no inbound connections to private subnet
- **Security groups** — restrict traffic on specific ports (8080, 5432, 5672, etc.)
- **ALB terminates HTTPS** — handles SSL/TLS, forwards HTTP to containers

---

## Day-by-Day Implementation Plan

### Days 1-2: Foundation & AWS Setup

**Goal:** Account ready, tools installed, repo structured

**Tasks:**
- Create AWS account, set up IAM user with admin access
- Install: AWS CLI, Terraform, Docker
- Configure billing alerts ($50, $75, $90 thresholds)
- Create repository structure

**Repository Structure:**
```
cloud-design/
├── README.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── provider.tf
│   └── modules/
│       ├── vpc/
│       ├── ecs/
│       ├── alb/
│       └── security/
├── docker/
│   ├── inventory-app/
│   │   └── Dockerfile
│   ├── billing-app/
│   │   └── Dockerfile
│   ├── api-gateway-app/
│   │   └── Dockerfile
│   ├── inventory-db/
│   │   └── Dockerfile
│   ├── billing-db/
│   │   └── Dockerfile
│   └── docker-compose.yml
├── ecs/
│   ├── task-definitions/
│   │   ├── inventory-app.json
│   │   ├── billing-app.json
│   │   ├── api-gateway-app.json
│   │   ├── rabbit-queue.json
│   │   ├── inventory-db.json
│   │   └── billing-db.json
│   ├── services/
│   └── cluster-config.json
├── monitoring/
│   └── cloudwatch-dashboard.json
└── scripts/
    ├── deploy.sh
    └── cleanup.sh
```

**Audit check:** ✅ Files present in repo

---

### Days 3-4: VPC & Networking (Terraform)

**Goal:** Isolated network with public/private subnets (1 AZ)

**Terraform Configuration:**
```hcl
# terraform/modules/vpc/
- VPC (10.0.0.0/16)
- 1 Public subnet (10.0.1.0/24) - ALB, NAT Gateway
- 1 Private subnet (10.0.2.0/24) - ECS (all 6 containers)
- Internet Gateway
- NAT Gateway (single, for cost)
- Route tables
- Security groups:
  - alb-sg: 80, 443 from 0.0.0.0/0
  - ecs-sg: 8080, 3000, 5672, 5432 from alb-sg only
```

**Audit check:** ✅ VPC isolation, databases only accessible from VPC

---

### Days 5-6: Build & Push to Docker Hub

**Goal:** Build optimized images and push to Docker Hub

**Tasks:**
1. Build all 6 Docker images locally
2. Test with docker-compose.yml
3. Tag and push to Docker Hub

**Push Commands:**
```bash
# Login
docker login

# Build and push (repeat for each)
docker build -t username/inventory-app:latest ./docker/inventory-app/
docker push username/inventory-app:latest

docker build -t username/billing-app:latest ./docker/billing-app/
docker push username/billing-app:latest

docker build -t username/api-gateway-app:latest ./docker/api-gateway-app/
docker push username/api-gateway-app:latest

# For databases, build custom Dockerfiles or use official images
docker build -t username/inventory-db:latest ./docker/inventory-db/
docker push username/inventory-db:latest

docker build -t username/billing-db:latest ./docker/billing-db/
docker push username/billing-db:latest
```

**Audit check:** ✅ All 6 images on Docker Hub, optimized Dockerfiles

---

### Days 7-8: Containerize Microservices

**Goal:** Optimized Docker images

**Dockerfile Example (Multi-stage, Alpine):**
```dockerfile
# inventory-app/Dockerfile
FROM node:18-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
RUN npm run build

FROM node:18-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
EXPOSE 8080
CMD ["node", "dist/index.js"]
```

**Tasks:**
- Build all 3 app images locally
- Test with docker-compose.yml
- Create ECR repositories, push images

**Audit check:** ✅ Optimized Dockerfiles, build times reduced

---

### Days 9-10: ECS Cluster & Services

**Goal:** All 6 containers running on ECS

**Terraform Configuration:**
```hcl
# terraform/modules/ecs/
- ECS Cluster
- EC2 instances (t3.micro, 2x for HA)
- IAM roles for ECS
- CloudWatch agent
```

**Task Definitions (6 total):**
1. `inventory-app`: port 8080, connects to inventory-db
2. `billing-app`: port 8080, connects to billing-db + rabbit-queue
3. `api-gateway-app`: port 3000, forwards to inventory-app/billing-app
4. `rabbit-queue`: port 5672/15672
5. `inventory-db`: PostgreSQL on port 5432, EBS volume for data
6. `billing-db`: PostgreSQL on port 5432, EBS volume for data

**Services:**
- `api-gateway`: behind ALB (public, port 3000)
- `inventory-app`: internal
- `billing-app`: internal
- `rabbit-queue`: internal
- `inventory-db`: internal, EBS volume mounted
- `billing-db`: internal, EBS volume mounted

**Audit check:** ✅ `aws ecs list-services`, `docker ps` shows all 6 running

---

### Day 11: ALB & Load Balancing

**Goal:** Traffic distribution + HTTPS

**Terraform Configuration:**
```hcl
# terraform/modules/alb/
- Application Load Balancer
- Target group for api-gateway (port 3000)
- Listener on port 443 (HTTPS)
- ACM certificate (free)
- Redirect HTTP → HTTPS
```

**Audit check:** ✅ Load balancing configured, HTTPS

---

### Day 12: Security & Cognito

**Goal:** Authentication + access control

**Terraform Configuration:**
```hcl
# Cognito User Pool
- User pool for API authentication
- App client for api-gateway
- JWT authorizer on ALB listener rules
```

**Test:**
- Request without auth → rejected (401)
- Request with valid JWT → allowed

**Audit check:** ✅ Unauthenticated requests rejected, Cognito configured

---

### Day 13: Monitoring & Auto-scaling

**Goal:** Observability + scaling

**CloudWatch Dashboard (JSON):**
- ECS CPU/Memory utilization
- RDS connections, query latency
- ALB request count, latency
- RabbitMQ queue depth

**Auto-scaling:**
- ECS Service: min=1, max=3, target CPU 70%
- EC2 Auto Scaling Group: min=2, max=4

**Test:** Send load, verify scaling triggers

**Audit check:** ✅ Dashboards visible, auto-scaling works

---

### Day 14: API Testing & Billing Resilience

**Goal:** Verify functionality + queue resilience

**Test Sequence:**
1. POST /movies through api-gateway → 201 Created
2. GET /movies through api-gateway → list of movies
3. Stop billing-app: `aws ecs update-service --desired-count 0`
4. Send billing request → should succeed (queued in RabbitMQ)
5. Restart billing-app: `aws ecs update-service --desired-count 1`
6. Verify billing-app processed queued request

**Audit check:** ✅ API Gateway works, billing resilience demonstrated

---

### Day 15: Documentation & Final Prep

**Goal:** README.md + audit readiness

**README.md Structure:**
```
# Cloud-Design

## Architecture
[Mermaid diagram]

## Components (6 Containers)
- api-gateway-app: Routes requests (port 3000)
- inventory-app: Handles inventory operations (port 8080)
- billing-app: Processes billing via RabbitMQ (port 8080)
- rabbit-queue: Message queue for async processing (port 5672)
- inventory-db: PostgreSQL database (port 5432)
- billing-db: PostgreSQL database (port 5432)

## Prerequisites
- AWS account with CLI configured
- Terraform installed
- Docker installed
- Docker Hub account

## Setup
1. Clone repo
2. cd terraform && terraform init && terraform apply
3. Build and push 6 Docker images to Docker Hub
4. Deploy ECS services

## Security
- HTTPS via ACM + ALB
- Cognito for API authentication
- All containers in private subnet

## Monitoring
- CloudWatch dashboard for metrics
- Centralized logging

## Cost Breakdown
- Total: ~$29 for 15 days
```

**Audit Prep:**
- Practice 13 role-play questions
- Prepare `terraform plan`/`apply` demo
- Test all `aws ecs` commands
- Verify `docker ps` locally

**Audit check:** ✅ Documentation complete, audit ready

---

## Audit Compliance Summary

| Audit Item | How We Meet It |
|------------|----------------|
| Repository files | ✅ All files present |
| Role-play (13 Qs) | ✅ Study sessions on Days 14-15 |
| Architecture (5 criteria) | ✅ Documented in README |
| README completeness | ✅ Diagrams, setup, config, usage |
| Deployment verification | ✅ `aws ecs` commands + `docker ps` |
| API Gateway POST/GET | ✅ Day 14 testing |
| Billing resilience | ✅ Day 14 testing |
| Terraform | ✅ All infra in code |
| Optimized Dockerfiles | ✅ Multi-stage builds |
| Monitoring dashboards | ✅ CloudWatch |
| Auto-scaling | ✅ ECS Service Auto Scaling |
| Security: HTTPS | ✅ ACM + ALB |
| Security: Cognito | ✅ Day 12 |
| Security: VPC | ✅ RDS in private subnets |

---

## Cost Efficiency Summary

- **ECS over EKS:** Saves $36 (no control plane)
- **EC2 over Fargate:** Saves ~$100+ (no per-second pricing)
- **Single NAT Gateway:** Saves ~$16 vs two
- **db.t3.micro:** Smallest RDS instance
- **CloudWatch free tier:** No extra monitoring cost

**Total: ~$41 for 15 days, well within $100 budget.**

---

## Next Steps

1. Start with Days 1-2: Foundation & AWS Setup
2. Proceed through each phase sequentially
3. Test at each phase before moving to next
4. Document as you go (easier than at the end)

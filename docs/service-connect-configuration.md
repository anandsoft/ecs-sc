# How Service Connect is configured in ecs-sc

This is the **create order** used in this repo. Skip a step and tasks stay in `PENDING` / `DEPROVISIONING`, or callers get `Could not resolve host`.

Traffic picture (ALB vs Connect): [alb-and-service-connect.md](alb-and-service-connect.md).

## What you are building

Service Connect is **not** an ALB and **not** VPC DNS. It is:

1. A Cloud Map **HTTP namespace**
2. `service_connect_configuration` on each **ECS service**
3. An **Envoy sidecar** ECS injects into every task (not in the Dockerfile)

Apps still call **HTTP** (`http://catalog:8080`). Envoy does TLS between tasks.

| Service | Terraform | `service { }` block | Result |
| --- | --- | --- | --- |
| UI | `service_connect_server = null` | omitted | Client only. Can *call* others. Not discoverable. |
| catalog | `dns_name = catalog`, port `8080` | present + TLS | Server `http://catalog:8080` |
| sales | `dns_name = sales`, port `8080` | present + TLS | Server `http://sales:8080` (also a client of catalog) |

---

## 1. Namespace + cluster (do this first)

File: `terraform/modules/ecs_cluster/main.tf`

```hcl
resource "aws_service_discovery_http_namespace" "this" {
  name = "ecs-sc.local"   # var.namespace
}

resource "aws_ecs_cluster" "this" {
  name = "...-cluster"
  service_connect_defaults {
    namespace = aws_service_discovery_http_namespace.this.arn
  }
}
```

Use an **HTTP** namespace (`aws_service_discovery_http_namespace`), not a private DNS namespace. All three services must use this **same ARN**.

---

## 2. TLS prerequisites (before catalog/sales services)

Needed only because this mesh uses **Service Connect TLS**.

| Resource | File | Must-haves |
| --- | --- | --- |
| Infrastructure IAM role | `terraform/modules/iam` | Trust `ecs.amazonaws.com`. Attach `AmazonECSInfrastructureRolePolicyForServiceConnectTransportLayerSecurity`. |
| Private CA | `terraform/modules/pca` | `usage_mode = SHORT_LIVED_CERTIFICATE`. Tag **`AmazonECSManaged = true`**. Install the CA cert (`aws_acmpca_certificate` + `_authority_certificate`) so the CA is `ACTIVE`. |
| KMS key | same module | Symmetric key. Key policy allows the TLS role `Encrypt` / `Decrypt` / `GenerateDataKey` / `CreateGrant`. |

Destroy **ECS services first**, then CA / KMS / role, or tasks can stick in draining.

---

## 3. Task definition: named port

Service Connect binds to a **named** `portMappings` entry. The name must match `port_name` later.

```hcl
portMappings = [{
  name          = "catalog-http"   # <-- this string is the contract
  containerPort = 8080
  hostPort      = 8080
  protocol      = "tcp"
  appProtocol   = "http"
}]
```

Sales uses `sales-http`. Network mode must be **`awsvpc`** (Fargate). UI’s published mapping is `ui-http` / `:80` for the **ALB**, not for Connect.

---

## 4. ECS service: `service_connect_configuration`

File: `terraform/modules/ecs_service/main.tf`  
Wired in: `terraform/main.tf`

**Every** service (including UI):

```hcl
service_connect_configuration {
  enabled   = true
  namespace = module.ecs_cluster.namespace_arn   # same namespace

  log_configuration {
    log_driver = "awslogs"
    options = {
      awslogs-group         = "/ecs/.../sc-ui"   # or sc-catalog / sc-sales
      awslogs-region        = var.aws_region
      awslogs-stream-prefix = "sc-proxy"
    }
  }
}
```

`enabled = true` with **no** inner `service` block = **client**. That is UI (`service_connect_server = null`).

**Servers** (catalog, sales) add:

```hcl
service {
  port_name      = "catalog-http"   # MUST equal portMappings.name
  discovery_name = "catalog"
  client_alias {
    dns_name = "catalog"            # what callers put in the URL
    port     = 8080                 # what callers put in the URL
  }
  tls {
    role_arn = module.iam.service_connect_tls_role_arn
    kms_key  = module.pca.kms_key_arn
    issuer_cert_authority {
      aws_pca_authority_arn = module.pca.pca_arn
    }
  }
}
```

Callers use `http://<dns_name>:<client_alias.port>/...` — here `http://catalog:8080` and `http://sales:8080`.

Create **catalog before sales**, **both backends before UI** (`depends_on` in `main.tf`).

---

## 5. App settings that must match the alias

| Caller | Setting | Value |
| --- | --- | --- |
| UI nginx | `proxy_pass http://${CATALOG_HOST}:${CATALOG_PORT}/` | `catalog` + `8080` |
| UI nginx | same for sales | `sales` + `8080` |
| sales | `CATALOG_BASE_URL` | `http://catalog:8080` |

**Do not** add nginx `resolver 10.0.0.2`. Connect writes names in **`/etc/hosts` → local Envoy**. VPC DNS skips that and the call never hits Service Connect.

Envsubst only those host/port variables so `$host` in nginx is left alone (`apps/ui/docker-entrypoint.sh`).

---

## 6. Security groups

Connect traffic hits **Envoy on the alias port** (`8080`), not “app to app” on a different port.

```text
ALB SG  :80  →  UI SG
UI SG   :8080 →  backend SG     # UI Envoy → catalog / sales
backend SG :8080 →  backend SG  # sales Envoy → catalog (self-ref)
```

Plus egress `:443` on tasks (ECR, logs, PCA, Secrets Manager). Catalog/sales are **not** ALB targets.

---

## 7. Checklist when Connect “does not work”

1. All services `enabled = true` and **same namespace ARN**.
2. Server `port_name` **equals** `portMappings.name`.
3. Caller URL is `http://<client_alias.dns_name>:<client_alias.port>` (HTTP, not HTTPS).
4. nginx has **no** `resolver`; hosts are static after envsubst.
5. CA is `ACTIVE`, tagged `AmazonECSManaged=true`, TLS role + KMS in place **before** the ECS service exists.
6. SG allows `:8080` UI→backend and backend→backend.
7. Envoy logs: log group `/ecs/<prefix>/sc-*`, stream prefix `sc-proxy`.
8. Local Docker Compose is **not** Service Connect — only DNS aliases. TLS/Envoy exist only in AWS.

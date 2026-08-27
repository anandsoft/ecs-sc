# ecs-sc

One **ECS Fargate cluster**, **three services**, each running **one microservice**. **ALB** is attached to UI only. **ECS Service Connect with TLS** carries UI → catalog, UI → sales, and sales → catalog.

How traffic moves: **[docs/alb-and-service-connect.md](docs/alb-and-service-connect.md)**. API contract: **[docs/openapi.yaml](docs/openapi.yaml)**. Swagger: `/swagger/` on the ALB (or [http://localhost:8080/swagger/](http://localhost:8080/swagger/) locally).

| | What |
| --- | --- |
| Cluster | `ecs-sc-dev-cluster` |
| Services | `ui` (ALB), `catalog` (Service Connect TLS), `sales` (Service Connect TLS) |
| Replicas | min **3**, max **9**, CPU target tracking |
| Namespace | `ecs-sc.local` |

```text
Browser
   │  north-south
   ▼
  ALB :80
   │  UI only
   ▼
┌────────────┐   Service Connect TLS                 ┌────────────┐
│ UI :80     │ ── GET  /products, /products/:id ───► │ catalog    │
│ nginx+SPA  │ ── GET  /images/:id.svg ────────────► │ :8080      │
│ 3–9 tasks  │                                       └──────▲─────┘
└──────┬─────┘                                              │
       │  Service Connect TLS                               │ GET /products/:id
       │  GET /prices, /prices/:id                          │ (confirm before buy)
       │  POST /orders                                      │
       ▼                                                    │
┌────────────┐   Service Connect TLS                        │
│ sales :8080│ ─────────────────────────────────────────────┘
└────────────┘
```

Apps still call **plain HTTP** (`http://catalog:8080`, `http://sales:8080`). The Service Connect Envoy sidecar terminates TLS. Certificates come from an **AWS Private CA in short-lived mode** (~$50/month). Do not use a general-purpose CA ($400/month) for this.

## Sample app

Anand's Store. Select a product, then buy. The browser only talks to the ALB. The UI proxies east-west calls:

| From | To | REST |
| --- | --- | --- |
| UI | catalog | `GET /products`, `GET /products/:id`, `GET /images/:id.svg` |
| UI | sales | `GET /prices`, `GET /prices/:id`, `POST /orders`, `GET /orders` |
| sales | catalog | `GET /products/:id` when an order is placed |

`POST /orders` body: `{ "productId": "h1", "quantity": 1 }`. Sales checks catalog over Service Connect, then decrements stock and returns the order.

Swagger UI: [http://localhost:8080/swagger/](http://localhost:8080/swagger/). Spec file: [`docs/openapi.yaml`](docs/openapi.yaml).

## Local

```bash
make local
# http://localhost:8080
```

Local Compose uses Docker DNS names `catalog` and `sales`. That stands in for Service Connect. TLS is AWS-only.

## Deploy to AWS

Private CA bills until you `make destroy`. Set `aws_profile` in `terraform.tfvars` if you use a named profile.

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
make init
make ecr-bootstrap
make images
make apply
terraform -chdir=terraform output alb_url
```

Destroy order is handled by Terraform. Destroying the cluster also deletes the Private CA after its 7-day waiting period starts.

## Design notes

- One task definition per service, one container per task, **one Dockerfile per microservice**.
- UI is Service Connect **client-only** (no `service {}` block). Catalog and sales **advertise** `catalog` and `sales` with TLS.
- ALB target group is UI container port 80. Catalog and sales have no load balancer.
- UI nginx uses a static `proxy_pass` after `envsubst`. Do not add `resolver 10.0.0.2`; that skips `/etc/hosts` where Service Connect writes names.
- Swagger UI is on the UI service at `/swagger/` (ALB). Try it out uses the same `/api/catalog` and `/api/sales` proxies.

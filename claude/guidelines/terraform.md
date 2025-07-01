# Terraform Guidelines

**Status:** GUIDELINES - Preferred approaches, deviations allowed with justification

**Purpose:** Standard patterns for infrastructure as code with Terraform.

---

## Three-Layer Model

**Principle:** Separation of configuration (what to deploy) and implementation (how to deploy).

### Layer 1: env/ (Configuration)

**Purpose:** Deployable infrastructure for specific environments

**Contains:**
- Environment-specific values
- Module compositions
- Remote state configuration

**Rules:**
- No complex logic
- No duplicated resources
- Calls modules (doesn't define resources directly)

**Example:**
```hcl
# env/portal-service/prod/main.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "portal-service/prod/terraform.tfstate"
    region = "us-east-1"
  }
}

module "api" {
  source = "../../../modules/lambda-api"

  function_name = "portal-api-prod"
  environment   = "prod"
  memory_size   = 512
  timeout       = 30
}
```

### Layer 2: modules/ (Project-Local)

**Purpose:** Reusable modules within this repository

**Contains:**
- Module implementations
- Resource definitions
- Variables and outputs

**Rules:**
- No environment-specific values
- Reusable across environments
- Well-documented inputs/outputs

**Example:**
```hcl
# modules/lambda-api/main.tf
resource "aws_lambda_function" "api" {
  function_name = var.function_name
  runtime       = "dotnet8"
  handler       = "Bootstrap::Bootstrap.LambdaEntryPoint::FunctionHandlerAsync"
  role          = aws_iam_role.lambda.arn

  architectures = ["arm64"]  # Graviton2 for cost savings

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }
}
```

### Layer 3: Internal Registry (Preferred)

**Purpose:** Modules reused across multiple repositories

**When:**
- Module used in 2+ repositories
- Stable, mature patterns
- Organizational standards

**Prefer registry over local modules** when possible.

---

## Cost Optimization Patterns

### Serverless-First

**Prefer:**
```hcl
# Lambda - pay per invocation
resource "aws_lambda_function" "api" {
  # Scales to zero, no cost when idle
}

# DynamoDB on-demand - pay per request
resource "aws_dynamodb_table" "main" {
  billing_mode = "PAY_PER_REQUEST"
}

# S3 - pay per GB stored
resource "aws_s3_bucket" "assets" {
  # Cheap storage, scales automatically
}
```

**Avoid (unless justified):**
```hcl
# RDS - always-on costs
resource "aws_db_instance" "main" {
  instance_class = "db.t3.micro"  # ~$15/month even at 0 traffic
}

# NAT Gateway - hourly costs
resource "aws_nat_gateway" "main" {
  # ~$30/month + data transfer
}
```

### Graviton2 ARM

**Use ARM64 for Lambda** (19% better performance, 20% lower cost):
```hcl
resource "aws_lambda_function" "api" {
  architectures = ["arm64"]  # ✅ Graviton2
  # architectures = ["x86_64"]  # ❌ More expensive
}
```

---

## Naming Conventions

**Resources:**
```hcl
# Format: {service}-{resource-type}-{environment}
resource "aws_lambda_function" "api" {
  function_name = "portal-api-prod"
  #                └─┬──┘ └┬┘ └─┬┘
  #                  │     │    └─ environment
  #                  │     └────── resource type
  #                  └──────────── service
}
```

**Variables:**
```hcl
variable "function_name" {}  # Snake_case
variable "memory_size" {}
variable "environment" {}
```

**Outputs:**
```hcl
output "function_arn" {}  # Snake_case
output "function_url" {}
```

---

## DynamoDB Patterns

### Single Table Design (Preferred)

```hcl
resource "aws_dynamodb_table" "main" {
  name         = "app-table-${var.environment}"
  billing_mode = "PAY_PER_REQUEST"

  hash_key  = "PK"
  range_key = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # GSI for alternate access patterns
  global_secondary_index {
    name            = "GSI1"
    hash_key        = "GSI1PK"
    range_key       = "GSI1SK"
    projection_type = "ALL"
  }

  attribute {
    name = "GSI1PK"
    type = "S"
  }

  attribute {
    name = "GSI1SK"
    type = "S"
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }
}
```

**Key Encoding:**
- PK: `USER#{userId}`, `ORG#{orgId}`
- SK: `PROFILE#METADATA`, `ORDER#{orderId}`
- GSI1PK/SK: Alternate access patterns

---

## CloudFront + S3 Static Site

```hcl
# S3 bucket for static assets
resource "aws_s3_bucket" "site" {
  bucket = "my-site-${var.environment}"
}

resource "aws_s3_bucket_public_access_block" "site" {
  bucket = aws_s3_bucket.site.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.site.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.site.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "S3-${aws_s3_bucket.site.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "S3-OAC-${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
```

---

## Remote State

**Always use remote state for env/:**

```hcl
# env/portal-service/prod/backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "portal-service/prod/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

**Benefits:**
- Team collaboration
- State locking
- Encrypted storage

---

## Module Documentation

**Every module must have README.md:**

```markdown
# Lambda API Module

## Purpose
Deploys a .NET Lambda function with API Gateway integration.

## Usage
\`\`\`hcl
module "api" {
  source = "../../../modules/lambda-api"

  function_name = "my-api-prod"
  environment   = "prod"
  memory_size   = 512
}
\`\`\`

## Inputs
| Name | Description | Type | Required |
|------|-------------|------|----------|
| function_name | Lambda function name | string | yes |
| environment | Environment (prod/staging) | string | yes |
| memory_size | Memory in MB | number | no (default: 256) |

## Outputs
| Name | Description |
|------|-------------|
| function_arn | Lambda function ARN |
| function_url | Function URL endpoint |
```

---

## Environment Isolation

**Separate state per environment:**

```
env/
  portal-service/
    prod/
      main.tf
      backend.tf      # Separate state
    staging/
      main.tf
      backend.tf      # Separate state
```

**No shared mutable state** between environments.

---

## Anti-Patterns

❌ **Avoid:**
- Resources directly in `env/` (use modules)
- Hardcoded values (use variables)
- Mutable shared state between environments
- Always-on infrastructure (prefer serverless)
- Unversioned provider/module sources
- No remote state

✅ **Prefer:**
- Module composition in `env/`
- Variables for configuration
- Isolated environment state
- Serverless services
- Pinned versions
- S3 backend with locking

---

*These are guidelines. Deviations allowed with documented rationale.*

## Environment Strategy

**Principle:** Explicit environments with isolated state, promotion via configuration.

### Environment Types

**Production (prod):**
- User-facing, the environment others depend on
- High availability, backups enabled
- Point-in-time recovery for DynamoDB
- Multi-AZ where applicable
- Strict change control

**Staging:**
- Pre-production testing
- Mirror of production (smaller scale)
- Integration testing
- Performance testing at scale
- Can be destroyed/recreated

**Sandbox (Optional):**
- Developer experimentation
- Short-lived (destroyed nightly via CI)
- Minimal cost (on-demand only)
- No data retention requirements

### Directory Structure

```
env/
├── portal-service/
│   ├── prod/
│   │   ├── main.tf
│   │   ├── backend.tf       # State: portal-service/prod/terraform.tfstate
│   │   └── terraform.tfvars
│   ├── staging/
│   │   ├── main.tf
│   │   ├── backend.tf       # State: portal-service/staging/terraform.tfstate
│   │   └── terraform.tfvars
│   └── sandbox/             # Optional
│       └── ...
├── mail-service/
│   ├── prod/
│   └── staging/
```

**Rules:**
- ✅ One service + one environment = one state file
- ✅ Each environment is independently deployable
- ✅ Destroy staging/sandbox without affecting prod
- ❌ No shared mutable infrastructure between environments
- ❌ No environment-specific logic in modules

### Environment-Specific Values

**terraform.tfvars (per environment):**

```hcl
# env/portal-service/prod/terraform.tfvars
environment       = "prod"
function_name     = "portal-api-prod"
memory_size       = 512
timeout           = 30
enable_backups    = true
enable_monitoring = true
log_retention     = 30

# env/portal-service/staging/terraform.tfvars
environment       = "staging"
function_name     = "portal-api-staging"
memory_size       = 256
timeout           = 30
enable_backups    = false
enable_monitoring = false
log_retention     = 7
```

### Promotion Strategy

**Promote configuration, not state:**

```hcl
# modules/lambda-api/main.tf
resource "aws_lambda_function" "api" {
  function_name = var.function_name
  memory_size   = var.memory_size
  timeout       = var.timeout
  
  # Environment determines behavior via variables
  environment {
    variables = {
      ENVIRONMENT = var.environment
      LOG_LEVEL   = var.environment == "prod" ? "INFO" : "DEBUG"
    }
  }
}
```

**Deploy same module version to staging first:**

```bash
# 1. Deploy to staging
cd env/portal-service/staging
terraform apply

# 2. Test in staging

# 3. Deploy same module to prod
cd env/portal-service/prod
terraform apply
```

### Environment Isolation

**Separate AWS accounts (optional but recommended):**

```hcl
# env/portal-service/prod/backend.tf
terraform {
  backend "s3" {
    bucket  = "prod-terraform-state"
    key     = "portal-service/prod/terraform.tfstate"
    region  = "us-east-1"
    profile = "prod-aws-account"  # Separate AWS account
  }
}

# env/portal-service/staging/backend.tf
terraform {
  backend "s3" {
    bucket  = "staging-terraform-state"
    key     = "portal-service/staging/terraform.tfstate"
    region  = "us-east-1"
    profile = "staging-aws-account"  # Separate AWS account
  }
}
```

**Single AWS account (cost-optimized for a solo developer):**

```hcl
# Isolation via naming and tagging
resource "aws_dynamodb_table" "main" {
  name = "${var.service_name}-${var.environment}"
  
  tags = {
    Environment = var.environment
    Service     = var.service_name
  }
}
```

### Cost Expectations by Environment

| Environment | Expected Monthly Cost | Characteristics |
|-------------|----------------------|-----------------|
| **Production** | Variable (usage-based) | On-demand billing, scales with traffic |
| **Staging** | Near-zero when idle | Destroyed when not testing |
| **Sandbox** | $0 | Destroyed nightly via CI |

**Example CI/CD for sandbox cleanup:**

```yaml
# .gitea/workflows/sandbox-cleanup.yml
name: Sandbox Cleanup
on:
  schedule:
    - cron: '0 2 * * *'  # 2 AM daily

jobs:
  destroy-sandbox:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Destroy sandbox
        run: |
          cd env/portal-service/sandbox
          terraform destroy -auto-approve
```

---

## Tagging Conventions

**Principle:** Consistent tagging for cost tracking, ownership, and lifecycle management.

### Required Tags (All Resources)

```hcl
locals {
  common_tags = {
    Environment = var.environment
    Service     = var.service_name
    ManagedBy   = "Terraform"
    Owner       = var.owner_email
    CostCenter  = var.cost_center
  }
}

resource "aws_lambda_function" "api" {
  function_name = var.function_name
  
  tags = merge(local.common_tags, {
    Component = "API"
  })
}

resource "aws_dynamodb_table" "main" {
  name = var.table_name
  
  tags = merge(local.common_tags, {
    Component = "Database"
  })
}
```

### Tag Definitions

| Tag | Purpose | Example | Required |
|-----|---------|---------|----------|
| **Environment** | Deployment environment | `prod`, `staging`, `sandbox` | ✅ Yes |
| **Service** | Service name | `portal-service`, `mail-service` | ✅ Yes |
| **ManagedBy** | Infrastructure tool | `Terraform` | ✅ Yes |
| **Owner** | Responsible party | `you@example.com` | ✅ Yes |
| **CostCenter** | Billing category | `engineering`, `product` | ✅ Yes |
| **Component** | Resource type | `API`, `Database`, `Storage` | ⚠️ Recommended |
| **Version** | Software version | `v1.2.3` | ⚠️ For deployments |
| **BackupPolicy** | Backup requirement | `daily`, `none` | ⚠️ For stateful resources |

### Cost Allocation Tags

**Enable in AWS Billing:**

1. Go to AWS Billing Console → Cost Allocation Tags
2. Activate: `Environment`, `Service`, `CostCenter`, `Owner`
3. Wait 24 hours for tags to appear in Cost Explorer

**Query costs by service:**

```bash
# AWS CLI - Get costs by service for last month
aws ce get-cost-and-usage \
  --time-period Start=2026-01-01,End=2026-01-31 \
  --granularity MONTHLY \
  --metrics BlendedCost \
  --group-by Type=TAG,Key=Service
```

### Tagging Enforcement

**Module-level tag enforcement:**

```hcl
# modules/lambda-api/variables.tf
variable "common_tags" {
  description = "Common tags applied to all resources"
  type        = map(string)
  
  validation {
    condition = contains(keys(var.common_tags), "Environment")
    error_message = "common_tags must include 'Environment' key"
  }
  
  validation {
    condition = contains(keys(var.common_tags), "Service")
    error_message = "common_tags must include 'Service' key"
  }
}

# modules/lambda-api/main.tf
resource "aws_lambda_function" "api" {
  tags = var.common_tags
}
```

**env/ usage:**

```hcl
# env/portal-service/prod/main.tf
module "api" {
  source = "../../../modules/lambda-api"
  
  common_tags = {
    Environment = "prod"
    Service     = "portal-service"
    ManagedBy   = "Terraform"
    Owner       = "you@example.com"
    CostCenter  = "engineering"
  }
}
```

---

## Cost-Aware Defaults

**Principle:** Modules default to cost-effective configurations, opt-in for expensive features.

### Lambda Defaults

```hcl
# modules/lambda-api/variables.tf
variable "memory_size" {
  description = "Memory in MB"
  type        = number
  default     = 256  # Cost-effective default
}

variable "timeout" {
  description = "Timeout in seconds"
  type        = number
  default     = 10   # Short timeout prevents runaway costs
}

variable "architectures" {
  description = "CPU architecture"
  type        = list(string)
  default     = ["arm64"]  # Graviton2 (19% better performance, 20% cheaper)
}

variable "reserved_concurrent_executions" {
  description = "Reserved concurrency (costly, opt-in only)"
  type        = number
  default     = -1  # -1 = no reservation (cost-free)
}

# modules/lambda-api/main.tf
resource "aws_lambda_function" "api" {
  function_name = var.function_name
  memory_size   = var.memory_size
  timeout       = var.timeout
  architectures = var.architectures
  
  reserved_concurrent_executions = var.reserved_concurrent_executions
  
  # Graviton2 ARM default
  runtime = "dotnet8"  # .NET 8 supports ARM
}
```

### DynamoDB Defaults

```hcl
# modules/dynamodb-table/variables.tf
variable "billing_mode" {
  description = "Billing mode"
  type        = string
  default     = "PAY_PER_REQUEST"  # On-demand, cost-effective default
}

variable "point_in_time_recovery" {
  description = "Enable PITR (adds cost, opt-in)"
  type        = bool
  default     = false  # Disabled by default, enable in prod
}

variable "deletion_protection" {
  description = "Prevent accidental deletion"
  type        = bool
  default     = false  # Disabled for staging/sandbox
}

# modules/dynamodb-table/main.tf
resource "aws_dynamodb_table" "main" {
  name         = var.table_name
  billing_mode = var.billing_mode
  
  point_in_time_recovery {
    enabled = var.point_in_time_recovery
  }
  
  deletion_protection_enabled = var.deletion_protection
}
```

**Production override:**

```hcl
# env/portal-service/prod/main.tf
module "database" {
  source = "../../../modules/dynamodb-table"
  
  table_name               = "portal-prod"
  point_in_time_recovery   = true   # Override: Enable for prod
  deletion_protection      = true   # Override: Protect prod data
}
```

### S3 Defaults

```hcl
# modules/s3-bucket/variables.tf
variable "versioning_enabled" {
  description = "Enable versioning (adds storage cost)"
  type        = bool
  default     = false  # Disabled by default
}

variable "lifecycle_rules" {
  description = "Lifecycle rules for cost optimization"
  type = list(object({
    id                       = string
    enabled                  = bool
    transition_days          = number
    transition_storage_class = string
  }))
  default = [
    {
      id                       = "transition-to-ia"
      enabled                  = true
      transition_days          = 30
      transition_storage_class = "STANDARD_IA"
    },
    {
      id                       = "transition-to-glacier"
      enabled                  = true
      transition_days          = 90
      transition_storage_class = "GLACIER"
    }
  ]
}

# modules/s3-bucket/main.tf
resource "aws_s3_bucket" "main" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_versioning" "main" {
  bucket = aws_s3_bucket.main.id
  
  versioning_configuration {
    status = var.versioning_enabled ? "Enabled" : "Suspended"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "main" {
  bucket = aws_s3_bucket.main.id
  
  dynamic "rule" {
    for_each = var.lifecycle_rules
    
    content {
      id     = rule.value.id
      status = rule.value.enabled ? "Enabled" : "Disabled"
      
      transition {
        days          = rule.value.transition_days
        storage_class = rule.value.transition_storage_class
      }
    }
  }
}
```

### CloudWatch Logs Defaults

```hcl
# modules/lambda-api/variables.tf
variable "log_retention_days" {
  description = "CloudWatch log retention (shorter = cheaper)"
  type        = number
  default     = 7  # Cost-effective default for non-prod
}

# modules/lambda-api/main.tf
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days
}
```

**Production override:**

```hcl
# env/portal-service/prod/main.tf
module "api" {
  source = "../../../modules/lambda-api"
  
  log_retention_days = 30  # Override: Keep prod logs longer
}
```

### Avoid Expensive Defaults

**❌ BAD: Expensive defaults:**

```hcl
variable "instance_type" {
  default = "t3.large"  # Always-on cost
}

variable "provisioned_capacity" {
  default = 100  # Provisioned DynamoDB (expensive)
}

variable "enable_nat_gateway" {
  default = true  # ~$30/month per NAT Gateway
}
```

**✅ GOOD: Cost-aware defaults:**

```hcl
variable "billing_mode" {
  default = "PAY_PER_REQUEST"  # On-demand
}

variable "enable_vpc_endpoints" {
  default = true  # Free alternative to NAT Gateway
}

variable "cloudfront_price_class" {
  default = "PriceClass_100"  # US/Europe only (cheapest)
}
```

### Cost Estimation in Modules

**Document expected costs in README:**

```markdown
# Lambda API Module

## Cost Expectations

**Default configuration:**
- Lambda invocations: $0.20 per 1M requests
- Lambda compute (arm64, 256MB, 10s avg): ~$0.0000033 per request
- CloudWatch Logs (7 day retention): ~$0.50/GB ingested
- **Total for 1M requests/month:** ~$1-5 depending on execution time

**Production configuration (512MB, 30s timeout):**
- **Total for 1M requests/month:** ~$3-10

**Cost optimization tips:**
- Use ARM64 architecture (included in defaults)
- Keep memory at 256MB unless profiling shows need
- Reduce timeout to minimum required
- Batch operations where possible
```

---

*These are guidelines. Deviations allowed with documented rationale.*

# Compliance Implementation Guidelines
## Senior Infra Review of `docs/compliance.md` vs `root/main.tf`

> **Scope**: Code-level actionable guidance cross-referenced against the actual `root/main.tf` and Terraform module wiring.
> This is an engineering supplement to `compliance.md`, not a legal opinion.

---

## Quick-Win Priority Matrix

| Priority | Control | Effort | Risk of doing nothing |
|----------|---------|--------|----------------------|
| 🔴 P0 | Remove `secretsmanager:PutSecretValue` from execution role | Low | Lateral movement blast radius |
| 🔴 P0 | `force_destroy`/`force_delete`/`skip_final_snapshot` → env variable | Low | Unrecoverable prod data loss |
| 🔴 P0 | `recovery_window_in_days = 0` on secrets module | Low | Instant secret deletion, no recovery |
| 🟠 P1 | KMS-backed encryption for S3, CloudWatch exec logs, Secrets Manager | Medium | Weak encryption posture, audit finding |
| 🟠 P1 | Narrow `CloudWatchLogsFullAccess` and SSM wildcard in IAM module | Medium | Overprivileged runtime nodes |
| 🟠 P1 | Enable CloudWatch exec log encryption | Low | Unencrypted session capture |
| 🟡 P2 | ALB access logs + deletion protection in prod | Low | No HTTP access audit trail |
| 🟡 P2 | WAF association on public frontend ALB | Medium | No L7 protection for internet traffic |
| 🟡 P2 | SNS KMS encryption | Low | SNS messages not encrypted at rest |
| 🟢 P3 | CloudTrail, AWS Config, GuardDuty | High | No account-level audit trail |
| 🟢 P3 | Secret rotation | Medium | Static credentials, no rotation evidence |
| 🟢 P3 | Incident response runbook | Low-doc | GDPR 72h breach window undefended |

---

## Segment 1: Encryption — KMS Migration

### What `main.tf` shows today
- `module "s3"` — no `kms_key_arn` input visible → defaults to AES256
- `module "secrets"` — no KMS key input → AWS-managed key
- `module "cw_logs"` — passes `ecs_exec_logs_name` to IAM but the exec log encryption is explicitly disabled in the ECS module (`cloud_watch_encryption_enabled = false`)
- `module "ecr"` — no KMS input → AES256
- `module "sns"` — no KMS input → plaintext at rest

### Concrete Implementation Steps

**Step 1 — Add a `kms` module to `root/main.tf`**

Create one KMS key per purpose to satisfy the principle of key separation required by HIPAA and recommended by SOC 2 auditors:

```hcl
module "kms" {
  source  = "hashicorp/aws/aws//modules/kms"  # or your own module
  # or use aws_kms_key resources directly:

  # S3 manifests key
  s3_manifests_key_description    = "${var.project_name}-${local.env_suffix}-s3-manifests"
  # CloudWatch exec logs key  
  exec_logs_key_description       = "${var.project_name}-${local.env_suffix}-exec-logs"
  # Secrets Manager key
  secrets_key_description         = "${var.project_name}-${local.env_suffix}-secrets"
  # SNS key
  sns_key_description             = "${var.project_name}-${local.env_suffix}-sns"

  enable_key_rotation = true  # Required: HIPAA and SOC 2 expect rotation
  deletion_window_in_days = var.kms_deletion_window_days  # 7 for dev, 30 for prod
}
```

**Step 2 — Wire KMS into existing modules**

Add these inputs to the relevant module calls. You will need to expose `kms_key_arn` as a new variable in the referenced GitLab module versions:

```hcl
module "s3" {
  # ... existing inputs ...
  kms_key_arn = module.kms.s3_manifests_key_arn
}

module "secrets" {
  # ... existing inputs ...
  kms_key_arn = module.kms.secrets_key_arn
}

module "sns" {
  # ... existing inputs ...
  kms_master_key_id = module.kms.sns_key_arn
}

# When you re-enable ecs_fargate exec logging:
module "ecs_fargate" {
  # ... existing inputs ...
  cloud_watch_encryption_enabled = true
  exec_logs_kms_key_arn         = module.kms.exec_logs_key_arn
}
```

**Step 3 — Add new root variables to `root/variables.tf`**

```hcl
variable "kms_deletion_window_days" {
  description = "KMS key deletion window. Use 7 for dev, 30 for prod."
  type        = number
  default     = 30
}

variable "kms_key_arn_s3_manifests" {
  description = "Optional externally managed KMS key ARN for S3 manifests. If empty, a key is created."
  type        = string
  default     = ""
}

variable "kms_key_arn_exec_logs" {
  description = "Optional externally managed KMS key ARN for CloudWatch exec logs."
  type        = string
  default     = ""
}

variable "kms_key_arn_secrets" {
  description = "Optional externally managed KMS key ARN for Secrets Manager."
  type        = string
  default     = ""
}
```

**KMS Key Policy — minimum required principals**

```json
{
  "Statement": [
    {
      "Sid": "AllowKeyAdministration",
      "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:role/terraform-deploy-role" },
      "Action": ["kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
                 "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
                 "kms:Get*", "kms:Delete*", "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"],
      "Resource": "*"
    },
    {
      "Sid": "AllowECSTaskEncrypt",
      "Principal": { "AWS": "arn:aws:iam::ACCOUNT_ID:role/ecs-task-execution-role" },
      "Action": ["kms:Decrypt", "kms:GenerateDataKey"],
      "Resource": "*"
    },
    {
      "Sid": "AllowCloudWatchLogs",
      "Principal": { "Service": "logs.amazonaws.com" },
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*", "kms:DescribeKey"],
      "Resource": "*"
    }
  ]
}
```

> [!IMPORTANT]
> `SNS` KMS requires you also grant `kms:GenerateDataKey` and `kms:Decrypt` to the SNS service principal (`sns.amazonaws.com`). Missing this causes silent encryption failure and delivery errors.

---

## Segment 2: IAM Least Privilege

### What `main.tf` shows today
`module "iam"` receives:
- `ecs_exec_logs_arn` → used inside the module for exec session log group
- `rds_db_address_arn` → from SSM
- `rdsdb_root_password_arn` → from Secrets Manager

The compliance doc calls out 4 specific IAM over-privileges in the IAM module itself. Since that module is on GitLab (`version = "0.2.14-iam-env-tag"`), you cannot patch it directly here — but you can override or supplement it from root.

### Concrete Implementation Steps

**Option A (preferred) — Override specific policies by attaching inline denies and replacements in root**

Create a `root/iam_patches.tf` to add scoped supplemental policies to the roles that the module creates:

```hcl
# Narrow down CloudWatchLogsFullAccess on the ECS node role
resource "aws_iam_role_policy" "ecs_node_cw_scoped" {
  name = "${var.project_name}-${local.env_suffix}-ecs-node-cw-scoped"
  role = module.iam.ecs_node_role_name  # expose this output if not already

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LogPublishOnly"
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/ecs/${var.project_name}-${local.env_suffix}*:*"
      }
    ]
  })
}

# Scope SSM access to app-specific path only
resource "aws_iam_role_policy" "ecs_task_ssm_scoped" {
  name = "${var.project_name}-${local.env_suffix}-ecs-task-ssm-scoped"
  role = module.iam.ecs_task_execution_role_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SSMPathScoped"
        Effect = "Allow"
        Action = ["ssm:GetParameters", "ssm:GetParameter"]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}:parameter/${var.project_name}/${local.env_suffix}/*"
      }
    ]
  })
}
```

**Option B — Bump module version with fixed policies**

When you next publish the IAM module to GitLab:
- Remove `secretsmanager:PutSecretValue` from the execution role (this is a **write** action; execution roles only need `GetSecretValue`)
- Replace `CloudWatchLogsFullAccess` with a custom policy scoped to the cluster log group ARN
- Replace `parameter/*` with `parameter/${project_name}/${env}/*`
- Replace `Resource = "*"` on ECS exec with the specific cluster ARN

**GitHub OIDC trust policy — add subject conditions**

Ensure your OIDC role trust policy includes `sub` conditions:

```json
{
  "Condition": {
    "StringLike": {
      "token.actions.githubusercontent.com:sub": [
        "repo:arsalanshaikh13/ecr-three-tier-modules:environment:prod",
        "repo:arsalanshaikh13/ecr-three-tier-modules:environment:dev"
      ]
    },
    "StringEquals": {
      "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
    }
  }
}
```

> [!WARNING]
> Without the `sub` condition, any workflow in your repository (or a compromised workflow) can assume the production deployment role, regardless of which branch or environment triggered it.

---

## Segment 3: Logging, Retention, and Evidence

### What `main.tf` shows today
`module "cw_logs"` already accepts:
- `app_log_retention_days`
- `ecs_exec_log_retention_days`

`module "s3"` accepts:
- `successful_manifest_retention_days`
- `noisy_manifest_retention_days`
- `noncurrent_manifest_version_retention_days`

This is already good structure. The gaps are in **what values are set per environment** and **missing account-level services**.

### Concrete Implementation Steps

**Step 1 — Set compliance-tiered retention per environment in `.tfvars`**

```hcl
# dev.tfvars
app_log_retention_days              = 30
ecs_exec_log_retention_days         = 30
successful_manifest_retention_days  = 90
noisy_manifest_retention_days       = 30
noncurrent_manifest_version_retention_days = 7

# prod.tfvars
app_log_retention_days              = 365   # HIPAA: 6 years; SOC 2: 1 year minimum
ecs_exec_log_retention_days         = 365
successful_manifest_retention_days  = 365
noisy_manifest_retention_days       = 90
noncurrent_manifest_version_retention_days = 90
```

**Step 2 — Add CloudTrail (critical for SOC 2 and HIPAA audit controls)**

```hcl
# root/cloudtrail.tf
resource "aws_cloudtrail" "main" {
  name                          = "${var.project_name}-${local.env_suffix}-trail"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_logs.id
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_log_file_validation    = true   # Integrity — HIPAA § 164.312(c)(1)

  kms_key_id = module.kms.exec_logs_key_arn  # reuse exec logs key or create dedicated

  event_selector {
    read_write_type           = "All"
    include_management_events = true

    # Capture S3 data events for the manifest bucket — provides deployment audit trail
    data_resource {
      type   = "AWS::S3::Object"
      values = ["${module.s3.manifest_bucket_arn}/"]
    }
  }

  tags = local.common_tags
}

# CloudTrail bucket — must have no public access and deny delete
resource "aws_s3_bucket" "cloudtrail_logs" {
  bucket = "${var.project_name}-${local.env_suffix}-cloudtrail"
  tags   = local.common_tags
}

resource "aws_s3_bucket_lifecycle_configuration" "cloudtrail_lifecycle" {
  bucket = aws_s3_bucket.cloudtrail_logs.id
  rule {
    id     = "expire-old-logs"
    status = "Enabled"
    expiration { days = var.cloudtrail_retention_days }
  }
}
```

**Step 3 — Add AWS Config (catches drift from compliant state)**

```hcl
# root/aws_config.tf
resource "aws_config_configuration_recorder" "main" {
  name     = "${var.project_name}-${local.env_suffix}-config"
  role_arn = aws_iam_role.config_role.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_config_delivery_channel" "main" {
  name           = "${var.project_name}-${local.env_suffix}-config"
  s3_bucket_name = aws_s3_bucket.cloudtrail_logs.id  # reuse or separate bucket
}
```

---

## Segment 4: Secrets — Recovery and Rotation

### What `main.tf` shows today
```hcl
module "secrets" {
  source       = "gitlab.com/arsalanshaikh13/ecr-three-tier-tf-modules/aws//secrets"
  version      = "0.1.1-secrets-tag"
  db_password  = module.rds.db_password  # ← RDS-generated password passed in
  env_suffix   = local.env_suffix
  project_name = var.project_name
}
```

The module currently has `recovery_window_in_days = 0` — this means if a secret is deleted (accidentally or by `terraform destroy`), it is **gone immediately with no 30-day safety net**.

### Concrete Implementation Steps

**Step 1 — Add `secret_recovery_window_days` to module interface**

In the `secrets` module, change:
```hcl
# Before
recovery_window_in_days = 0

# After
recovery_window_in_days = var.secret_recovery_window_days
```

In `root/main.tf`:
```hcl
module "secrets" {
  # ... existing ...
  secret_recovery_window_days = var.secret_recovery_window_days
}
```

In `root/variables.tf`:
```hcl
variable "secret_recovery_window_days" {
  description = "Secrets Manager recovery window. 0 is dangerous in prod. Use 7-30 for prod."
  type        = number
  default     = 7
}
```

In `dev.tfvars`: `secret_recovery_window_days = 0` (acceptable for dev)  
In `prod.tfvars`: `secret_recovery_window_days = 30`

**Step 2 — Add RDS secret rotation**

```hcl
# root/secrets_rotation.tf
resource "aws_secretsmanager_secret_rotation" "rds_password" {
  count               = var.enable_secret_rotation ? 1 : 0
  secret_id           = module.secrets.rdsdb_root_password_arn
  rotation_lambda_arn = aws_lambda_function.secret_rotator.arn

  rotation_rules {
    automatically_after_days = var.secret_rotation_days  # 90 is SOC 2 common baseline
  }
}
```

> [!NOTE]
> AWS provides a managed Lambda for RDS password rotation (`arn:aws:serverlessrepo:us-east-1:912272126650:applications/SecretsManagerRDSPostgreSQLRotationSingleUser`). This is the lowest-effort path to satisfying the rotation requirement.

---

## Segment 5: Network Security

### What `main.tf` shows today
- `module "lb"` — frontend ALB on public subnets, backend ALB on private subnets ✓
- `module "sg"` — separate SGs per tier ✓
- No WAF module visible
- `deletion_protection` not passed to `lb` module

### Concrete Implementation Steps

**Step 1 — ALB access logs (quick win, ~5 lines)**

```hcl
module "lb" {
  # ... existing inputs ...
  access_logs_enabled    = var.alb_access_logs_enabled
  access_logs_bucket     = aws_s3_bucket.alb_logs.id
  deletion_protection    = var.alb_deletion_protection_enabled
}

variable "alb_access_logs_enabled" {
  type    = bool
  default = false  # dev default
}

variable "alb_deletion_protection_enabled" {
  type    = bool
  default = false  # dev default; set true in prod.tfvars
}
```

In `prod.tfvars`:
```hcl
alb_access_logs_enabled         = true
alb_deletion_protection_enabled = true
```

**Step 2 — WAF for the public frontend ALB**

```hcl
# root/waf.tf
resource "aws_wafv2_web_acl" "frontend" {
  count = var.waf_enabled ? 1 : 0
  name  = "${var.project_name}-${local.env_suffix}-frontend-waf"
  scope = "REGIONAL"

  default_action { allow {} }

  # AWS Managed Rule Groups — free baseline, no custom rules required
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "CommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2
    override_action { none {} }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "KnownBadInputs"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-${local.env_suffix}-waf"
    sampled_requests_enabled   = true
  }

  tags = local.common_tags
}

resource "aws_wafv2_web_acl_association" "frontend_alb" {
  count        = var.waf_enabled ? 1 : 0
  resource_arn = module.lb.frontend_alb_arn
  web_acl_arn  = aws_wafv2_web_acl.frontend[0].arn
}

variable "waf_enabled" {
  description = "Enable WAF for the public frontend ALB."
  type        = bool
  default     = false  # dev default; set true in prod.tfvars
}
```

**Step 3 — Restrict egress on ECS node SG**

Current SG module likely has open egress (`0.0.0.0/0`). In the `sg` module, egress should be:

```hcl
# ECS nodes only need to reach:
# - ECR (HTTPS 443) via VPC endpoint or NAT
# - Secrets Manager (HTTPS 443)
# - CloudWatch (HTTPS 443)
# - RDS (db_port, only from backend SG)
# - ALB (tg_port)

egress_rules = [
  { protocol = "tcp", from_port = 443, to_port = 443, cidr = "0.0.0.0/0", description = "HTTPS to AWS services" },
  { protocol = "tcp", from_port = var.db_port, to_port = var.db_port, source_sg = module.sg.ecs_node_rds_sg_id, description = "DB access" }
]
```

---

## Segment 6: Destructive Defaults

### What `main.tf` shows today
These flags are set in module defaults, not visible in root:
- `s3` module: `force_destroy = true`
- `ecr` module: `force_delete = true`
- `rds` module: `skip_final_snapshot = true`
- `secrets` module: `recovery_window_in_days = 0`

### Concrete Implementation Steps

Add these to `root/variables.tf` and expose as inputs to each module:

```hcl
variable "allow_force_destroy" {
  description = "Allow S3 buckets to be force-destroyed. Set false in prod."
  type        = bool
  default     = true
}

variable "allow_force_delete" {
  description = "Allow ECR repos to be force-deleted. Set false in prod."
  type        = bool
  default     = true
}

variable "rds_skip_final_snapshot" {
  description = "Skip final RDS snapshot on destroy. Set false in prod."
  type        = bool
  default     = true
}

variable "rds_deletion_protection" {
  description = "Enable RDS deletion protection. Set true in prod."
  type        = bool
  default     = false
}
```

Wire into modules:
```hcl
module "s3"   { force_destroy        = var.allow_force_destroy    }
module "ecr"  { force_delete         = var.allow_force_delete      }
module "rds"  {
  skip_final_snapshot = var.rds_skip_final_snapshot
  deletion_protection = var.rds_deletion_protection
}
```

In `prod.tfvars`:
```hcl
allow_force_destroy     = false
allow_force_delete      = false
rds_skip_final_snapshot = false
rds_deletion_protection = true
```

> [!CAUTION]
> Once `deletion_protection = true` is applied to an RDS instance, `terraform destroy` will fail unless you first `terraform apply` with `deletion_protection = false`. This is intentional — it is the protection working. Document this in your runbook.

---

## Segment 7: Change Management — CI Enforcement

### What exists today
`deploy.yml` has: guardrails, manifest recording, SBOM hook, security scan hook.

### What is missing
- No mandatory Terraform linting/scanning gate in CI
- `enable_security_scan` and `enable_sbom` are optional inputs with `default: false`

### Concrete Implementation Steps

**Step 1 — Create `terraform-ci.yml` workflow**

```yaml
# .github/workflows/terraform-ci.yml
name: Terraform CI

on:
  pull_request:
    paths:
      - "root/**"
      - "modules/**"

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "~1.7"
      - run: terraform -chdir=root fmt -check -recursive
      - run: terraform -chdir=root init -backend=false
      - run: terraform -chdir=root validate

  security-scan:
    runs-on: ubuntu-latest
    needs: validate
    steps:
      - uses: actions/checkout@v4
      - name: Run Checkov
        uses: bridgecrewio/checkov-action@master
        with:
          directory: root
          framework: terraform
          soft_fail: false   # FAIL the PR on HIGH/CRITICAL IaC findings
          output_format: sarif
          output_file_path: checkov-results.sarif

      - name: Upload SARIF to GitHub Security tab
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: checkov-results.sarif
```

**Step 2 — Make security scan mandatory for prod in `deploy.yml`**

In `deploy.yml`, add a guard to the `build-and-deploy` job:

```yaml
  - name: Enforce security scan for prod
    if: contains(fromJson(needs.detect-changes.outputs.matrix), 'prod') && !inputs.enable_security_scan
    run: |
      echo "::error::enable_security_scan=true is required for prod-targeting deployments."
      exit 1
```

---

## Segment 8: Incident Response — Runbook Structure

This is documentation work, not Terraform, but critical for GDPR 72h breach notification and HIPAA §164.308(a)(6).

### Files to Create

**`docs/incident_response.md`** — minimum structure:

```markdown
## Severity Classification
- SEV1: Active data breach or ePHI/PII exposure
- SEV2: Service degraded, potential data integrity issue
- SEV3: Operational failure, no data impact

## Detection Sources
| Source | Alarm | Escalation path |
|--------|-------|-----------------|
| SNS release-notifications topic | ALB 5xx > threshold | On-call → Slack |
| CloudWatch ECS CPU alarm | CPU > 90% | On-call |
| GuardDuty finding | High/Critical | Security lead → CISO |

## GDPR Breach Response
- Detection to internal escalation: < 1 hour
- DPA notification (if warranted): < 72 hours from awareness
- Evidence: CloudTrail, CloudWatch, deployment manifests

## HIPAA Incident Procedures (§164.308(a)(6))
- Identify and respond to security incidents
- Mitigate harmful effects
- Document incidents and outcomes

## Rollback Decision Authority
- SEV1: Any engineer with prod access
- SEV2: On-call engineer
- SEV3: Team lead approval

## Evidence Preservation
- Do NOT delete CloudWatch log groups before incident closure
- Export relevant logs to S3 immediately
- Tag the deployment manifest with incident reference
```

**`docs/break_glass.md`** — document that `break_glass_reason` input in `deploy.yml` must:
- Reference a Jira/ServiceNow ticket
- Be reviewed within 24h by security lead
- Trigger an automatic SNS notification to a dedicated security alert topic

---

## Summary of New Variables to Add to `root/variables.tf`

```hcl
# Encryption
variable "kms_deletion_window_days"     { type = number; default = 30 }

# Secrets
variable "secret_recovery_window_days"  { type = number; default = 7 }
variable "enable_secret_rotation"       { type = bool;   default = false }
variable "secret_rotation_days"         { type = number; default = 90 }

# Destructive defaults
variable "allow_force_destroy"          { type = bool;   default = true }
variable "allow_force_delete"           { type = bool;   default = true }
variable "rds_skip_final_snapshot"      { type = bool;   default = true }
variable "rds_deletion_protection"      { type = bool;   default = false }

# Network
variable "waf_enabled"                  { type = bool;   default = false }
variable "alb_access_logs_enabled"      { type = bool;   default = false }
variable "alb_deletion_protection_enabled" { type = bool; default = false }

# Audit
variable "cloudtrail_retention_days"    { type = number; default = 365 }

# Change management
variable "security_scan_required_for_prod" { type = bool; default = false }
variable "sbom_required_for_prod"          { type = bool; default = false }
```

And a recommended `prod.tfvars` override block:

```hcl
# prod.tfvars — compliance overrides
kms_deletion_window_days           = 30
secret_recovery_window_days        = 30
enable_secret_rotation             = true
allow_force_destroy                = false
allow_force_delete                 = false
rds_skip_final_snapshot            = false
rds_deletion_protection            = true
waf_enabled                        = true
alb_access_logs_enabled            = true
alb_deletion_protection_enabled    = true
cloudtrail_retention_days          = 365
security_scan_required_for_prod    = true
sbom_required_for_prod             = true
```

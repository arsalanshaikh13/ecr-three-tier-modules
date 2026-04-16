# Compliance Readiness Review for DevOps, GitHub Actions, Terraform, and AWS

## Scope and Boundary

This document is a repo-focused compliance readiness review, not a legal opinion, certification, or audit report.

It checks how the current GitHub Actions workflows, Terraform code, and AWS infrastructure patterns in this repository align with compliance-relevant requirements for:

- GDPR
- SOC 2
- HIPAA

This review focuses on controls that are visible from code and pipeline behavior. Some requirements cannot be proven from repo contents alone and still require organization-level policies, contracts, evidence, HR controls, incident response procedures, and formal audit artifacts.

## Compliance Standards and Why They Matter Here

### GDPR

For this repo, the most relevant GDPR themes are:

- Article 5: integrity, confidentiality, storage limitation, accountability
- Article 25: data protection by design and by default
- Article 32: security of processing
- Articles 33 and 34: breach notification and response readiness

In practical DevOps terms, GDPR pushes this platform toward:

- least-privilege access
- encryption for sensitive data and logs
- retention limits
- auditability
- restricted secrets exposure
- documented incident handling

### SOC 2

SOC 2 is usually mapped through the Trust Services Criteria. The most relevant categories here are:

- Security
- Availability
- Confidentiality
- Processing Integrity
- Privacy, if personal data is in scope

For this repo, SOC 2 mostly means:

- change management
- access control
- logging and monitoring
- incident detection and response
- configuration management
- evidence that controls are consistently enforced

### HIPAA

HIPAA is only relevant if this system stores, processes, or transmits ePHI and the organization has the appropriate legal and vendor relationships in place, including a BAA where required.

For this repo, the most relevant HIPAA Security Rule themes are:

- Administrative safeguards
- Physical safeguards
- Technical safeguards

At the infrastructure and pipeline layer, that translates into:

- access control
- audit controls
- integrity controls
- transmission security
- minimum necessary access
- security incident procedures

## Current Repo-Visible Readiness Summary

These are rough code-level readiness estimates, not certification percentages.

| Framework | Repo-visible readiness | Short reading                                                                                                                                                                                                                               |
| --------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| GDPR      | Moderate               | Good security baseline in several places, but encryption scope, retention governance, IAM scoping, and breach/evidence processes are incomplete.                                                                                            |
| SOC 2     | Moderate               | Stronger than average engineering hygiene, especially around environment gating and release traceability, but not yet audit-ready in least privilege, evidence collection, review enforcement, and operational policy coverage.             |
| HIPAA     | Low to Moderate        | Some good foundations exist, but current defaults are not strong enough for regulated ePHI workloads without tighter IAM, stronger encryption choices, safer deletion defaults, audit retention hardening, and organization-level controls. |

## What the Current Repo Already Does Well

### GitHub Actions / Deployment Workflow Strengths

- Uses GitHub OIDC federation instead of long-lived AWS access keys.
- Uses environment-scoped jobs and prod approval separation in promotion flow.
- Has predeploy guardrails, promotion controls, rollback flows, and manifest-based release traceability.
- Uses reusable workflows and actions, which is good for standardization and auditability.
- Uses deployment manifests plus S3-backed release history, which improves accountability and rollback transparency.

### Terraform / AWS Strengths

- ECR repositories use immutable tags.
- ECR image scanning on push is enabled.
- S3 manifest bucket has versioning enabled.
- S3 manifest bucket blocks public access.
- S3 manifest bucket uses server-side encryption.
- RDS is not publicly accessible.
- Secrets are injected into ECS task definitions through Secrets Manager references rather than hardcoded plaintext environment values.
- CloudWatch log groups and container insights are enabled.
- CloudWatch alarms, telemetry gates, and SNS email notifications now exist, which helps with monitoring and incident detection.

### Operational Design Strengths

- Release manifests and release history improve traceability.
- Manual prod approval exists in workflow topology.
- Rollback targeting is smarter than a simple latest-pointer approach.
- SBOM and image security hooks exist in the workflow design, even if they may not always be enforced by default.

## Current Repo-Visible Gaps and Compliance Risks

## Segment 1: Encryption and Data Protection Gaps

### Current Match

- S3 bucket encryption exists.
- ECR encryption exists.
- EFS transit encryption is enabled for Fargate backend volumes.
- Secrets are stored in Secrets Manager rather than checked into code.

### Gaps

- S3 and ECR currently use `AES256` instead of customer-managed KMS keys.
- ECS execute-command CloudWatch log encryption is explicitly disabled with `cloud_watch_encryption_enabled = false`.
- Secrets Manager secret does not show customer-managed KMS usage.
- RDS code shown does not explicitly enable storage encryption in the visible module.
- There is no repo-visible KMS key rotation strategy for regulated logs, secrets, or deployment metadata.

### Why This Matters

- GDPR Article 32 expects security appropriate to risk.
- HIPAA technical safeguards strongly favor stronger encryption discipline where sensitive workloads exist.
- SOC 2 auditors commonly expect a defensible encryption strategy, especially for secrets, logs, backups, and sensitive operational metadata.

### Required Improvements

- Move S3 manifest bucket encryption to SSE-KMS with a customer-managed key.
- Move ECR encryption to KMS where supported by your design and cost model.
- Enable CloudWatch exec log encryption and back it with a KMS key.
- Use customer-managed KMS for Secrets Manager secrets that protect application secrets or database credentials.
- Confirm and explicitly set RDS storage encryption in Terraform if not already enabled elsewhere.
- Add KMS key rotation configuration and key policies scoped to required principals only.

### Implementation Guidance

Terraform:

- Add dedicated KMS module or KMS resources for:
  - manifest bucket
  - CloudWatch exec logs
  - Secrets Manager
  - optionally ECR and SNS
- Pass KMS ARNs into `modules/s3`, `modules/cw_logs`, `modules/secrets`, and any other storage/logging modules.

AWS:

- Separate keys by purpose where practical.
- Restrict decrypt permissions narrowly.
- Log key usage with CloudTrail.

## Segment 2: IAM and Least Privilege

### Current Match

- Roles are separated between task, execution, and EC2 node roles.
- OIDC is used in GitHub Actions rather than static cloud keys.
- ECS tasks do not appear to receive S3 manifest permissions unnecessarily.

### Gaps

- EC2 node role has `CloudWatchLogsFullAccess`, which is broader than necessary.
- ECS execution role policy includes `secretsmanager:PutSecretValue`, which is unusually broad for runtime secret consumption.
- SSM parameter access is wildcarded to `parameter/*` across regions.
- ECS exec policy uses `Resource = "*"`.
- Repo-visible workflow permissions are reasonable at the GitHub level, but AWS role policies are not yet fully minimal.

### Why This Matters

- GDPR and HIPAA both expect access limited to what is necessary.
- SOC 2 strongly depends on enforceable least privilege.
- Broad runtime and node privileges are a classic audit finding.

### Required Improvements

- Replace AWS managed broad policies with narrower custom policies where possible.
- Remove `secretsmanager:PutSecretValue` from ECS execution role unless there is a real runtime write requirement.
- Scope SSM parameter access to app-specific paths like `/${project_name}/${env}/*`.
- Replace `CloudWatchLogsFullAccess` with write-only or log-group-scoped permissions.
- Review GitHub OIDC role trust policies for branch, environment, and repository restrictions.

### Implementation Guidance

Terraform:

- Refactor IAM into smaller policy documents per use case:
  - log publishing
  - image pulling
  - secret read only
  - parameter read only
  - ECS exec session transport
- Add variable-driven ARNs and path prefixes rather than region-wide wildcards.

GitHub Actions:

- Keep `permissions` blocks minimal per workflow.
- Restrict OIDC trust relationships to:
  - repository
  - workflow or ref patterns
  - environment when applicable

## Segment 3: Logging, Auditability, and Evidence Retention

### Current Match

- CloudWatch logs are enabled for workloads.
- CloudWatch telemetry and alarms exist.
- Deployment history is now tracked via S3 manifests and manifest index.
- SNS notifications exist for release and alarm events.

### Gaps

- CloudWatch retention settings are present but not clearly compliance-tiered.
- Execute-command log encryption is disabled.
- There is no repo-visible CloudTrail, AWS Config, GuardDuty, Security Hub, or centralized audit log strategy.
- There is no immutable evidence storage pattern for approvals, deployments, break-glass events, and rollback justifications beyond normal GitHub/AWS logs.
- `force_destroy` and `force_delete` patterns weaken evidence retention and safe data handling expectations.

### Why This Matters

- SOC 2 and HIPAA both care about audit controls and traceability.
- GDPR accountability expectations benefit from durable evidence and defined retention.
- Destructive convenience settings are often acceptable in labs but become problematic in regulated environments.

### Required Improvements

- Define retention classes for:
  - app logs
  - exec logs
  - manifests
  - rollback evidence
  - security scan outputs
- Enable CloudTrail organization or account-level logging if not already present outside this repo.
- Add AWS Config and optionally Security Hub / GuardDuty in the wider environment.
- Remove or tightly control `force_destroy = true` and `force_delete = true` in production paths.

### Implementation Guidance

Terraform:

- Convert current retention values into root variables per environment.
- Add S3 lifecycle policies instead of relying on force deletion.
- Add separate retention defaults for dev and prod.
- Add optional CloudTrail / Config / GuardDuty modules if you want this repo to own them.

GitHub Actions:

- Persist security scan and SBOM artifacts with retention settings.
- Write break-glass approvals and change-ticket references into the deployment manifest payload consistently.

## Segment 4: Secrets, Sensitive Data Handling, and Data Minimization

### Current Match

- Secrets are referenced via Secrets Manager and SSM rather than embedded directly in task definitions.
- RDS is not publicly accessible.

### Gaps

- Secrets module uses `recovery_window_in_days = 0`, which is aggressive for regulated environments.
- The current secret management pattern needs a stronger rotation story.
- There is no visible data classification layer separating regulated vs non-regulated workloads.
- There is no repo-visible redaction control for logs that might contain sensitive application payloads.

### Why This Matters

- GDPR data minimization and storage limitation push toward tighter secret and data handling.
- HIPAA requires stronger discipline around access, retention, and recovery.
- SOC 2 expects controlled handling of confidential data.

### Required Improvements

- Increase Secrets Manager recovery window for production secrets.
- Add secret rotation where practical.
- Separate regulated and non-regulated environments if personal or health data is in scope.
- Review application logging to ensure secrets, tokens, and personal data are not emitted.

### Implementation Guidance

Terraform:

- Add `secret_recovery_window_days` as an environment-specific variable.
- Add rotation resources or document why rotation is out of scope.

Application and runtime:

- Add log redaction policy and application-level structured logging rules.
- Avoid putting sensitive values into deployment manifests, job summaries, or notifications.

## Segment 5: Network Security and Exposure

### Current Match

- Backend load balancer is internal.
- RDS is private.
- Security groups are segmented between frontend, backend, and database tiers.
- Network-mode-aware SG logic is improving and aligns better with runtime behavior.

### Gaps

- Frontend ALB allows public ingress from `0.0.0.0/0`, which is normal for public apps but requires compensating controls.
- Security group egress is broadly open.
- There is no repo-visible AWS WAF integration.
- Load balancer deletion protection is commented out rather than enforced.
- There is no visible TLS policy hardening, certificate governance, or ALB access log strategy in the reviewed code.

### Why This Matters

- Public exposure is acceptable when deliberate, but compliance expects layered controls.
- SOC 2 and HIPAA generally expect stronger network boundary management around internet-facing systems.
- GDPR expects risk-appropriate security for exposed systems handling personal data.

### Required Improvements

- Add WAF for the public ALB if internet-facing regulated traffic is possible.
- Restrict egress where practical, especially from compute nodes and tasks.
- Enable ALB access logging.
- Turn on load balancer deletion protection in production.
- Validate TLS-only ingress and modern TLS policies.

### Implementation Guidance

Terraform:

- Add optional WAF module and ALB association.
- Add ALB access logging bucket and lifecycle policy.
- Parameterize and enable deletion protection in prod.
- Review whether all outbound `0.0.0.0/0` egress is truly required.

## Segment 6: Change Management and Workflow Governance

### Current Match

- Promotion flow has prod approval separation.
- Deploy flow has predeploy guardrails.
- Release manifests, rollback history, and telemetry gates improve traceability.
- GitHub environments are used for deployment boundaries.

### Gaps

- Repo-visible branch protection, CODEOWNERS, required reviews, and signed commit enforcement are not represented in code.
- Some controls still depend on manual GitHub UI configuration rather than declarative enforcement.
- There is no repo-visible policy-as-code layer for Terraform scanning or workflow linting as mandatory gates.
- Security scan and SBOM features appear optional rather than mandatory in all sensitive deployment paths.

### Why This Matters

- SOC 2 depends heavily on documented and enforced change management.
- GDPR and HIPAA both benefit from stronger approval, traceability, and unauthorized change prevention.

### Required Improvements

- Make security scan and SBOM generation required for production-targeting changes.
- Enforce Terraform fmt/validate/tflint/checkov or equivalent in CI.
- Enforce branch protection and required reviewers outside the repo if not manageable in code.
- Document and log break-glass use formally.

### Implementation Guidance

GitHub Actions:

- Add mandatory jobs for:
  - Terraform validation
  - IaC security scanning
  - workflow linting
  - dependency and secret scanning
- Fail prod deploys if SBOM or image scan is skipped.

GitHub platform settings:

- Configure:
  - branch protection
  - required reviews
  - CODEOWNERS
  - signed commits if needed
  - environment protection rules

## Segment 7: Backup, Recovery, and Safe Destruction

### Current Match

- Release history and rollback logic are improving.
- S3 versioning provides some manifest recovery support.

### Gaps

- RDS uses `skip_final_snapshot = true`.
- S3 bucket uses `force_destroy = true`.
- ECR repositories use `force_delete = true`.
- Secrets Manager recovery window is set to zero days.

### Why This Matters

- These settings are convenient for development, but they are weak defaults for regulated environments.
- SOC 2 availability and recovery expectations generally favor safer destruction controls.
- HIPAA and GDPR both become harder to defend when deletion is too easy and recovery is too thin.

### Required Improvements

- Use environment-specific safe deletion defaults.
- Disable force-destroy behavior in prod.
- Require final snapshots for production databases unless an approved exception exists.
- Define backup retention and restore test cadence.

### Implementation Guidance

Terraform:

- Add variables such as:
  - `allow_force_destroy`
  - `allow_force_delete`
  - `rds_skip_final_snapshot`
  - `deletion_protection_enabled`
- Set dev and prod differently.

Operations:

- Document restore tests.
- Keep evidence of backup and restore exercises for SOC 2 and HIPAA readiness.

## Segment 8: Incident Response and Breach Readiness

### Current Match

- Alarms, telemetry, and SNS notifications improve runtime visibility.
- Manifest history and deployment evidence help with forensic reconstruction.

### Gaps

- There is no repo-visible incident response runbook, breach classification procedure, or notification matrix.
- There is no formal evidence collection path for security incidents.
- There is no documented mapping from alarm conditions to escalation severity.

### Why This Matters

- GDPR breach response timelines are strict.
- HIPAA requires security incident procedures.
- SOC 2 expects defined incident detection, response, and communication processes.

### Required Improvements

- Add incident response documentation and escalation matrix.
- Distinguish operational alerts from security alerts.
- Add a security incident workflow for:
  - alarm triage
  - evidence capture
  - rollback decision
  - postmortem logging

### Implementation Guidance

Repo docs:

- Add `incident_response.md`
- Add `break_glass.md`
- Add escalation and evidence expectations for deploy, rollback, and alarm events

AWS and ops:

- Route critical alarms to a dedicated SNS topic or incident channel rather than mixing all notices together.

## Repo-Visible Compliance Match by Domain

| Control domain                        | Current match     | Notes                                                                                                           |
| ------------------------------------- | ----------------- | --------------------------------------------------------------------------------------------------------------- |
| Encryption at rest                    | Partial           | Present in several places, but mostly AES256 defaults rather than stronger KMS-backed design.                   |
| Encryption for logs and exec sessions | Partial to weak   | App logs exist, but exec log encryption is disabled.                                                            |
| Least privilege IAM                   | Partial           | Role separation exists, but policy scope is broader than compliance-ready.                                      |
| Secrets handling                      | Partial           | Good direction, but recovery, rotation, and write permissions need tightening.                                  |
| Change control                        | Partial           | Strong workflow structure, but not fully mandatory or fully declarative.                                        |
| Audit logging and evidence            | Partial           | Good release evidence, incomplete account-level and immutable audit story.                                      |
| Backup and recovery                   | Weak to partial   | Some release history exists, but destructive defaults and DB snapshot settings are too weak for regulated prod. |
| Monitoring and incident detection     | Partial to strong | Telemetry and SNS are good foundations.                                                                         |
| Data minimization and retention       | Partial           | Some retention exists, but compliance-tier retention policy is not yet complete.                                |
| Network boundary protection           | Partial           | Reasonable segmentation, but public exposure needs more compensating controls.                                  |

## Implementation Roadmap for the Current Workflow and Infrastructure

## Phase A: High-Priority Hardening

- Enable KMS-backed encryption for:
  - S3 manifests
  - CloudWatch exec logs
  - Secrets Manager
  - optionally SNS and ECR
- Remove `secretsmanager:PutSecretValue` from runtime execution role unless required.
- Replace `CloudWatchLogsFullAccess` and broad SSM wildcard access with narrower policies.
- Disable `force_destroy` and `force_delete` in prod.
- Require final DB snapshot in prod.
- Make SBOM and security scan mandatory for prod-targeting deployments.

## Phase B: Auditability and Governance

- Add Terraform and workflow security scanning gates.
- Add branch protection and required review enforcement.
- Add CloudTrail, AWS Config, and optionally Security Hub / GuardDuty if not already managed elsewhere.
- Add ALB access logs and WAF for the public frontend boundary.
- Separate operational SNS notifications from security or compliance alerts.

## Phase C: Regulated-Workload Readiness

- Add documented incident response and breach handling procedures.
- Add secret rotation and restore testing evidence.
- Introduce data classification and retention policy by environment and workload type.
- Add a compliance profile switch so dev and prod defaults differ intentionally.

## Recommended Variables and Control Knobs to Add

Terraform variables that would make compliance implementation cleaner:

- `kms_key_arn_s3_manifests`
- `kms_key_arn_exec_logs`
- `kms_key_arn_secrets`
- `kms_key_arn_sns`
- `allow_force_destroy`
- `allow_force_delete`
- `rds_skip_final_snapshot`
- `rds_deletion_protection`
- `secret_recovery_window_days`
- `alb_access_logs_enabled`
- `alb_deletion_protection_enabled`
- `waf_enabled`
- `security_scan_required_for_prod`
- `sbom_required_for_prod`

## Honest Bottom Line

The current repo is much closer to "security-conscious platform engineering" than to "compliance-ready regulated platform."

That is not a criticism. The foundations are genuinely good:

- OIDC
- environment gating
- release manifests
- rollback traceability
- image immutability
- scanning hooks
- monitoring and notification

But for GDPR, SOC 2, and especially HIPAA-sensitive workloads, the current code still needs stronger:

- least privilege
- encryption choices
- destructive control defaults
- retention governance
- audit evidence strategy
- platform-level governance outside Terraform and workflow YAML

## References

Official sources used as control anchors:

- GDPR text on EUR-Lex:
  - https://eur-lex.europa.eu/legal-content/LV-EN/ALL/?from=EN&uri=CELEX%3A32016R0679
- HHS HIPAA Security Rule overview:
  - https://www.hhs.gov/hipaa/for-professionals/security/laws-regulations/index.html
- AICPA SOC resources:
  - https://www.aicpa-cima.com/soc

Summary

Created [compliance.md](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/ecr-three-tier-modules/docs/compliance.md).

What’s in it:

- GDPR, SOC 2, and HIPAA requirements relevant to DevOps, GitHub Actions, Terraform, and AWS
- a repo-visible readiness assessment
- clear segmentation by control area
- current matches vs gaps
- implementation guidance split by GitHub Actions, Terraform, and AWS
- a prioritized roadmap

Main repo findings called out in the doc:

- strong foundations:
  - OIDC-based AWS auth in workflows
  - environment/prod approval boundaries
  - immutable ECR images and scan-on-push
  - manifest history, rollback traceability, telemetry, SNS notifications
- important gaps:
  - broad IAM scopes in [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/iam/main.tf)
  - exec log encryption disabled in [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/ecs_fargate/main.tf) and [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/ecs_ec2/main.tf)
  - destructive convenience flags in [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/s3/main.tf), [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/ecr/main.tf), [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/rds/main.tf), and [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/secrets/main.tf)
  - public edge and open egress patterns in [main.tf](C:/Users/DELL/ArsVSCode/CS50p_project/project_aFinal/website/website2_0/animations/scroll/aws_three_tier_arch/three-tier-terragrunt/ecr/terraform-ecr/terraform_modules/tf-modules/ecr-three-tier-tf-modules/modules/sg/main.tf)

References included in the doc:

- EUR-Lex GDPR text
- HHS HIPAA Security Rule overview
- AICPA SOC resources

Important framing in the doc:

- this is a readiness mapping, not a legal certification
- SOC 2 and HIPAA cannot be satisfied by repo code alone
- several controls still require org/process configuration outside Terraform and workflow YAML

Natural next steps:

1. I can turn the “Phase A: High-Priority Hardening” section into actual Terraform/workflow patches.
2. I can add a second doc mapping each recommendation to exact files and modules to change.
3. I can produce a checklist version for implementation tracking.

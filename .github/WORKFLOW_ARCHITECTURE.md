# Workflow Architecture

## Overview

The top-level [`deploy.yml`](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\.github\workflows\deploy.yml) is now primarily an orchestration workflow.

It is responsible for:
- trigger handling
- change detection
- matrix calculation
- calling reusable workflows

Most step-level cloud mechanics now live in composite actions under `.github/actions`, while most job-level orchestration now lives in reusable workflows under `.github/workflows`.

## Reusable Workflows

- [`reusable-deploy-service.yml`](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\.github\workflows\reusable-deploy-service.yml)
  Handles one deploy unit for a component/environment pair.

- [`reusable-probe-environment.yml`](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\.github\workflows\reusable-probe-environment.yml)
  Runs post-deploy app probes, surfaces logs, and updates deployment pointers/manifests.

- [`reusable-auto-rollback.yml`](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\.github\workflows\reusable-auto-rollback.yml)
  Performs automatic rollback using the last-known-good SSM pointer after failed probes.

- [`reusable-manual-rollback.yml`](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\.github\workflows\reusable-manual-rollback.yml)
  Performs operator-driven rollback using explicit ARN, manifest history, or SSM fallback.

- [`reusable-seed-database.yml`](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\.github\workflows\reusable-seed-database.yml)
  Builds/runs the database seeder and records seeding-specific manifests.

## Manifest Types

Deployment and recovery history is intentionally split into several manifest categories so S3 serves as an audit trail while SSM remains the pointer store.

- Deployment success manifests
  Produced by `reusable-probe-environment.yml` after probe success.

- Deployment failure manifests
  Produced by `reusable-probe-environment.yml` after probe failure.

- Automatic rollback manifests
  Produced by `reusable-auto-rollback.yml`.

- Manual rollback manifests
  Produced by `reusable-manual-rollback.yml`.

- Seeding success manifests
  Produced by `reusable-seed-database.yml`.

- Seeding failure manifests
  Produced by `reusable-seed-database.yml`.

## Design Notes

- SSM stores trusted deployment pointers such as last-known-good task definition ARNs.
- S3 stores the auditable manifest history across deploy, rollback, and seeding operations.
- Reusable workflows own job-level orchestration.
- Composite actions own repeated ECS/ECR/SSM/S3 mechanics.
- Environment-scoped GitHub variables decide networking and environment-specific behavior without forcing workflow edits.

## Contract Style

Reusable workflows now follow a tighter shared contract so the top-level orchestrator can call them with the same mental model across deploy, probe, rollback, and seeding.

Common inputs across reusable workflows:
- environment
- project_name
- env_var
- `aws_region`
- `aws_account_id`
- manifest_bucket when the workflow persists deployment history

Workflow-specific inputs are still allowed, but the shared cloud/runtime identity fields now use one naming convention everywhere. This keeps call sites easier to scan and makes reuse across other repositories less error-prone.

Reusable workflows also expose a clearer output contract now. Where a workflow produces a durable deployment outcome, it exposes stable output names such as:
- `task_definition_arn`
- `previous_task_definition_arn`
- `image_uri`
- `probe_status`
- `probe_reason`
- `rollback_target_task_definition_arn`
- `seeding_status`
- `seeding_reason`

That keeps the workflows symmetric: callers can quickly understand both what they must provide and what they can safely consume.

Generated deployment metadata and manifest JSON use camelCase, while workflow and action contracts keep snake_case. That split is intentional: JSON stays friendly to JavaScript consumers, while workflow inputs and outputs stay shell-friendly and consistent with GitHub Actions conventions.

## Action vs Workflow Boundary

What stays action-level:
- ECR login, image build, and image fetch mechanics
- ECS task-definition download, render, and registration
- ECS task/service execution helpers
- ECS task wait/result/log collection
- deployment pointer read/write helpers
- deployment manifest write helpers

What stays workflow-level:
- trigger routing and matrix expansion
- environment-scoped orchestration and approval boundaries
- deploy, probe, rollback, and seeding choreography
- artifact coordination between jobs
- success/failure branching and promotion decisions
- operator-facing rollback resolution policy

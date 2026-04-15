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
- build_image / fetch_image when image policy is relevant
- component when the workflow targets one deployable unit
- manifest-related inputs only when the workflow persists deployment history

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

## Execution Flexibility

The current architecture intentionally allows the main execution workflows to support all ECS runtime/network combinations that the target environment supports:

- `EC2 + non-awsvpc`
- `EC2 + awsvpc`
- `FARGATE + awsvpc`

Why we chose this:
- it keeps deploy, probe, and seeding symmetric instead of giving one job artificial limitations
- it reflects how ECS actually separates launch type from network mode
- it makes the workflows reusable across environments that are not all on the same runtime model
- it supports migration paths where one environment is still EC2 while another has moved to Fargate

Boundary-wise, this means:
- `.github/actions/ecs-run-task` owns non-awsvpc execution
- `.github/actions/ecs-run-task-awsvpc` owns awsvpc execution, network lookup, and network JSON construction
- reusable workflows decide which action to use
- top-level orchestration or environment configuration decides which execution mode should apply

## Running-Version Drift

The current working implementation has a few important refinements beyond the earlier architecture notes. These are not accidental differences. They are the decisions that made the pipeline reliable in real `dev` and `prod` runs.

### 1. Region Is Explicit at the ECS Action Boundary

Earlier architecture notes focused on environment binding inside reusable workflows, which remains correct. Real multi-region execution made one more rule necessary:

- reusable workflows should pass `AWS_REGION` explicitly into the ECS runner and rollback action layer

Why this matters:
- it keeps ECS calls deterministic across `dev` and `prod`
- it prevents the action layer from depending too heavily on ambient CLI defaults
- it makes debugging wrong-region behavior much simpler

### 2. Operator Defaults Are Concrete, Not Abstract

The architecture now prefers concrete workflow-dispatch defaults:

- `EC2` or `FARGATE`
- `awsvpc` or `non-awsvpc`

instead of an abstract `auto` mode.

Why this drift happened:
- `auto` looked flexible, but in practice it hid too much behavior
- manual testing became harder to reason about
- reviewers could not immediately see what runtime shape a dispatch would use

This keeps runtime decisions visible while still allowing job-level overrides where needed.

### 3. Probe Stays Capability-Flexible but Is Operationally Pinned to Fargate

Architecturally, probe supports:

- `EC2 + non-awsvpc`
- `EC2 + awsvpc`
- `FARGATE + awsvpc`

Operationally, the top-level workflow now pins probe-style jobs to:

- `probe_launch_type: FARGATE`
- `probe_network_mode: awsvpc`

for normal probe and rollback-verification probe paths.

Why this drift happened:
- real runs showed EC2 probe tasks were slower to stop
- probe is a short-lived verification workload, so fast lifecycle behavior matters more than mirroring every service runtime choice

### 4. Temporary awsvpc Fallbacks Exist in Reusable Workflows

The ideal architecture prefers:

- explicit caller inputs first
- environment variables second

In practice, some reusable workflows now include temporary awsvpc fallback resolution for:

- subnet tag values
- security group names
- `assign_public_ip`

Why this drift happened:
- the pipeline needed to stay runnable while environment wiring was still being standardized

This is a pragmatic working-version decision, not the final ideal-state contract.

### 5. Environment Binding Is a Correctness Rule

The architecture already moved environment-scoped value resolution into reusable workflows. Real failures confirmed that this is not just cleaner design. It is a hard correctness rule.

Caller-side resolution can bind too early and produce cross-environment mistakes such as:

- prod execution paths resolving dev ECR repositories
- wrong environment variables leaking into reusable workflow execution

So the practical rule is:
- top-level workflows orchestrate
- reusable workflows bind to the GitHub environment and resolve environment-scoped values locally

### 6. Rollback Must Follow the Real Service Runtime

Rollback no longer assumes EC2-shaped recovery. It now follows the real service execution model and supports:

- `EC2 + non-awsvpc`
- `EC2 + awsvpc`
- `FARGATE + awsvpc`

This keeps rollback aligned with deploy instead of treating recovery as a special legacy path.

### 7. Change Detection Was Tightened to Match Deploy Intent

Push-based deployment is now intentionally narrower:

- deployable app paths can trigger push-based deployment
- workflow-only edits should not imply deploy intent
- branch-vs-main drift is not treated as current deploy intent

Manual dispatch remains the correct mechanism for workflow experimentation and runtime testing.

## Why These Drifts Matter

The architecture became successful not just because it was modular, but because the running version tightened a few critical boundaries:

1. environment scoping
2. region scoping
3. runtime/network scoping
4. deploy-trigger intent
5. probe and rollback operational behavior

That is the difference between a clean design and a dependable pipeline.

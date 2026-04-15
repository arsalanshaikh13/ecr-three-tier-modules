# Senior Engineer Prompt for CI/CD Pipeline Architecture

Use this prompt when you want an LLM to design, review, or recreate the CI/CD pipeline architecture implemented in this repository.

---

You are a senior platform engineer designing a production-grade CI/CD pipeline for a multi-component ECS-based application platform.

Your task is to produce a list-oriented, implementation-ready architecture specification for a reusable CI/CD system that supports GitHub Actions today and can be replicated with minimal architectural reinterpretation in GitLab CI and CircleCI.

The system being designed must reflect the following operating model, constraints, contracts, and implementation lessons.

## 1. Primary Objective

Design a CI/CD pipeline architecture that:

1. supports multi-component application delivery
2. supports multi-environment delivery, especially `dev` and `prod`
3. supports multi-region execution where `dev` and `prod` may use different AWS regions
4. deploys containerized workloads to ECS
5. supports both service deploys and one-off task executions
6. supports `EC2 + non-awsvpc`, `EC2 + awsvpc`, and `FARGATE + awsvpc` where applicable
7. supports post-deploy verification, automatic rollback, manual rollback, rollback verification, database seeding, and promotion
8. is modular enough to be implemented with:
   - top-level orchestration workflows
   - reusable job-level workflows
   - low-level reusable actions or commands
9. is explicit enough that the same architecture can be rebuilt in:
   - GitHub Actions
   - GitLab CI
   - CircleCI

## 2. System Context

Assume the application platform contains at least these deployable units:

1. `frontend`
2. `backend`
3. `probe`
4. `database-seeder`

Assume infrastructure is bootstrapped by Terraform, but runtime application revisions are created by CI/CD.

This means:

1. Terraform is not the source of truth for deployed application revisions
2. ECS task definition revisions are created dynamically during CI/CD
3. rollback cannot rely on Terraform state
4. operational deployment state must be managed explicitly by the pipeline

## 3. State Model

Design the pipeline around three distinct state stores with different responsibilities.

### 3.1 ECS

Use ECS as:

1. the task definition revision ledger
2. the runtime service/task execution platform

### 3.2 SSM Parameter Store

Use SSM as the trusted pointer store.

Store at least:

1. `current-task-definition-arn`
2. `last-known-good-task-definition-arn`

Store them per:

1. project
2. environment
3. component

### 3.3 S3

Use S3 as the durable audit/history store.

Store manifests for at least:

1. deployment success
2. deployment failure
3. automatic rollback
4. manual rollback
5. rollback verification success
6. rollback verification failure
7. seeding success
8. seeding failure
9. promotion events

You must keep the responsibilities distinct:

1. ECS = revision history
2. SSM = trusted rollback/deployment pointers
3. S3 = auditable manifest history

## 4. Required Pipeline Stages

Design the pipeline with explicit stages or equivalent logical phases.

### 4.1 Detect Changes

The pipeline must:

1. detect which deployable paths changed
2. determine target environments
3. avoid treating workflow-only edits as deploy intent on push events
4. support manual dispatch for explicit testing and targeted runs
5. handle zero-SHA push cases explicitly
6. compare a push against the immediately preceding pushed commit, not against `main`

### 4.2 Deploy Service

The deploy stage must:

1. resolve whether to build or fetch an image
2. prepare and register a new ECS task definition revision
3. update the ECS service to the new revision
4. persist deployment metadata for downstream jobs
5. not consider the deployment fully successful until probe passes

### 4.3 Probe Deployment

The probe stage must:

1. verify the deployed application surface
2. run as an ECS task
3. collect exit code, stop reason, and logs
4. update trusted pointers only on successful deployment probe
5. write deployment success or failure manifests

### 4.4 Automatic Rollback

Automatic rollback must:

1. trigger when deployment probe fails
2. resolve rollback target from `last-known-good-task-definition-arn`
3. never rely on latest-minus-one heuristics
4. never rely on Terraform state as the deployed revision source
5. update ECS service to the trusted rollback target
6. reset pointers to the recovery target
7. write rollback manifests

### 4.5 Rollback Verification Probe

Rollback verification must:

1. run after automatic rollback succeeds
2. verify that recovery actually restored healthy behavior
3. use the same core probe mechanics as deployment probe
4. not advance pointers on success
5. write rollback verification manifests
6. fail the workflow if recovery verification fails

### 4.6 Manual Rollback

Manual rollback must support this resolution order:

1. explicit task definition ARN
2. manifest record selection
3. SSM last-known-good fallback

It must then:

1. update ECS service to the chosen rollback target
2. update trusted pointers to the chosen target
3. write manual rollback manifests
4. run manual rollback verification probe

### 4.7 Database Seeding

Database seeding must:

1. run as a one-off ECS task
2. support build/fetch image policy explicitly
3. capture logs and exit status
4. write success/failure manifests
5. remain operationally separate from deployment success

### 4.8 Promotion

Promotion must:

1. promote an already validated lower-environment image to production
2. use successful lower-environment manifests as the promotion source of truth
3. copy the image into the production-region production ECR repository
4. write promotion manifests
5. trigger production deploy using the promoted image
6. avoid rebuilding production images when the intent is artifact promotion

## 5. Architectural Layers

Your design must explicitly separate three layers.

### 5.1 Top-Level Orchestration Layer

This layer should own:

1. trigger definitions
2. workflow dispatch inputs
3. change detection
4. matrix construction
5. environment routing
6. high-level policy decisions
7. promotion invocation
8. approval gates

This layer should not own low-level AWS mechanics.

### 5.2 Reusable Workflow Layer

This layer should own:

1. environment-bound job orchestration
2. approval boundary application
3. deploy/probe/rollback/seeding lifecycle choreography
4. artifact handoff between jobs
5. manifest and pointer transition decisions
6. runtime/network branching between awsvpc and non-awsvpc execution helpers

This layer should bind to the target environment and resolve environment-scoped values inside the bound job.

### 5.3 Reusable Action/Command Layer

This layer should own:

1. ECR login/build/push/fetch mechanics
2. ECS task definition download/render/register
3. ECS task execution
4. ECS service update execution
5. ECS task/service wait helpers
6. log collection
7. deployment pointer read/write helpers
8. manifest write helpers
9. awsvpc network lookup and valid JSON assembly for AWS CLI usage

This layer should be operational, composable, and reusable.

## 6. Contract Rules

Your design must define and enforce contract conventions.

### 6.1 Workflow and action contracts

Use `snake_case` for workflow/action inputs and outputs.

Examples:

1. `task_definition_arn`
2. `probe_status`
3. `rollback_target_task_definition_arn`
4. `build_image`
5. `fetch_image`

### 6.2 JSON contracts

Use `camelCase` for deployment metadata and manifests.

Examples:

1. `taskDefinitionArn`
2. `previousTaskDefinitionArn`
3. `imageUri`
4. `workflowRunId`

### 6.3 Compatibility

The design should recommend tolerant readers during migration windows so older manifest styles do not immediately break rollback or promotion.

## 7. Environment and Region Rules

Your design must make the following explicit.

### 7.1 Environment binding rule

Environment-scoped CI variables must be resolved inside reusable workflows bound to the target environment.

Do not resolve environment-dependent values too early in the top-level caller if that can cause:

1. prod jobs to inherit dev values
2. wrong ECR repository selection
3. wrong account or region selection

### 7.2 Region rule

The design must treat region as explicit at the action boundary.

Even if the CI environment exports `AWS_REGION`, reusable workflows should treat region intent as part of the environment-bound execution contract and pass it explicitly into low-level ECS execution helpers.

This is especially important for:

1. dev/prod multi-region deployments
2. rollback execution
3. one-off ECS tasks

## 8. Runtime and Network Flexibility

The architecture must support all meaningful ECS execution combinations:

1. `EC2 + non-awsvpc`
2. `EC2 + awsvpc`
3. `FARGATE + awsvpc`

You must explain:

1. why deploy, probe, seeding, and rollback should all be capability-flexible
2. why non-awsvpc execution belongs in a generic ECS run helper
3. why awsvpc execution belongs in a dedicated awsvpc helper that owns network lookup and JSON assembly
4. why `FARGATE` must only be used with `awsvpc`

## 9. Operator Defaults and Overrides

The design must support both:

1. workflow-level default runtime/network inputs for testing convenience
2. job-level overrides when a specific job must differ from the default

Use concrete operator-facing values only:

1. `EC2` or `FARGATE`
2. `awsvpc` or `non-awsvpc`

Do not use abstract `auto` defaults.

Explain the precedence model clearly. A recommended precedence is:

1. job-specific override
2. top-level workflow default
3. environment-scoped variable
4. safe built-in fallback

## 10. Probe-Specific Operating Rules

The design must make a distinction between architectural flexibility and operational defaults.

### 10.1 Probe capability

Probe should support:

1. `EC2 + non-awsvpc`
2. `EC2 + awsvpc`
3. `FARGATE + awsvpc`

### 10.2 Probe operational default

Probe should be operationally pinned to:

1. `FARGATE`
2. `awsvpc`

Explain why:

1. probe is a short-lived verification workload
2. faster start/stop matters more than matching every service runtime choice
3. the architecture should stay flexible while the operational default stays fast

### 10.3 Probe image strategy

Support explicit modes:

1. build-only
2. fetch-only
3. fetch-first with build fallback

Require these current operating behaviors:

1. normal deployment probe = fetch-first with build fallback
2. rollback verification probe = fetch-only
3. later probe runs should reuse ECR images when possible

## 11. Rollback Design Rules

Your design must emphasize that rollback is not just an ECS update.

### 11.1 Trusted target rule

Rollback target must come from trusted pointers or explicit operator choice, not heuristic revision guessing.

### 11.2 Runtime alignment rule

Rollback must follow the actual service runtime model, including:

1. launch type
2. network mode
3. awsvpc networking inputs when required

### 11.3 Verification rule

Rollback must always be followed by verification probe.

### 11.4 Pointer rule

Rollback verification must not promote pointers.

## 12. Seeding Design Rules

The design must describe seeding as an operational action, not a hidden deploy sub-step.

Include these rules:

1. seeding uses its own task definition
2. seeding uses its own build/fetch image policy
3. seeding writes its own manifests
4. seeding failures must still write manifests before failing the run
5. seeding can run in any supported ECS execution mode that the environment permits

## 13. Promotion Design Rules

The design must specify:

1. promotion source of truth is a successful lower-environment manifest
2. production should deploy promoted artifacts, not rebuild them unnecessarily
3. approval should happen before production promotion/deploy
4. production deployment should reuse the normal deploy workflow with fetch policy against the prod repository

## 14. Change Detection Rules

The design must explicitly specify change-detection intent.

Include these rules:

1. push-based deployment should only trigger for deployable application paths
2. workflow-only edits should not imply deploy intent
3. branch-vs-main drift must not be treated as current push diff
4. zero-SHA cases must be handled explicitly
5. manual dispatch remains the right path for workflow testing and targeted experiments

## 15. Manifest and Metadata Requirements

Require the architecture to define:

1. deployment metadata fields for workflow-local artifact handoff
2. durable manifest fields for S3 audit history
3. manifest path taxonomy for success/failure/rollback/seeding/promotion
4. clear distinction between workflow-local metadata and durable manifests

## 16. IAM and Security Expectations

The design must specify IAM requirements for CI identity and task execution, including at minimum:

1. ECR push/pull
2. ECS describe/register/update/run/stop
3. IAM pass role where required
4. EC2 describe for network lookup
5. CloudWatch Logs read
6. SSM get/put for pointers
7. S3 get/put/list for manifests

Prefer short-lived federated identity such as OIDC.

## 17. Observability and Failure Handling

Require the architecture to surface:

1. probe logs
2. seeder logs
3. rollback reasons
4. manifest upload results
5. image URIs used in deploy/promotion
6. explicit distinction between initial deploy failure and rollback verification failure

Failure handling must specify:

1. probe failure leads to automatic rollback
2. rollback verification failure fails the workflow
3. seeding writes manifests before failing
4. rollback target resolution failure fails fast with context

## 18. Replication Guidance

Require the output to include guidance for mapping the same architecture into:

1. GitHub Actions
2. GitLab CI
3. CircleCI

The design must map equivalent concepts such as:

1. top-level orchestration
2. reusable workflows/templates
3. reusable commands/actions
4. artifacts/workspaces
5. environment-scoped variables
6. manual approval gates

## 19. Documentation Expectations

The output you generate must be:

1. list-oriented
2. detailed
3. implementation-ready
4. opinionated about boundaries and contracts
5. explicit about which design decisions came from real execution lessons

The output should include these sections at minimum:

1. System Goals
2. System Components
3. State Model
4. Workflow Layers
5. Deployment Flow
6. Probe Flow
7. Rollback Flow
8. Seeding Flow
9. Promotion Flow
10. Contracts and Conventions
11. Runtime and Network Model
12. Environment and Region Model
13. Change Detection Model
14. Failure Handling
15. Security and IAM
16. Portability to GitLab and CircleCI
17. Working-Version Refinements

## 20. Tone and Standard

Write the result as a senior engineer would:

1. precise
2. structured
3. operationally realistic
4. explicit about tradeoffs
5. clear about default behavior versus optional flexibility
6. opinionated where ambiguity would create production risk

Do not write a shallow overview.

Do not optimize for brevity.

Optimize for a document that another engineer could use to recreate the pipeline architecture in a different CI system with minimal guesswork.

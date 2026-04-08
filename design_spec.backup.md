# CI/CD Pipeline Design Specification

## Purpose

This document specifies the design of a reusable ECS-based CI/CD pipeline that is currently implemented in GitHub Actions and is intended to be replicable in GitLab CI and CircleCI with minimal architectural reinterpretation.

The goal is not to describe one vendor-specific YAML file. The goal is to describe the pipeline as a portable deployment system with clearly separated concerns:

- orchestration
- cloud mechanics
- deployment state
- deployment history
- promotion strategy
- rollback and rollback verification
- environment-scoped configuration

This specification should be detailed enough that the same system can be rebuilt in:

- GitHub Actions
- GitLab CI
- CircleCI

without changing the underlying deployment design.

---

## 1. System Goals

### 1.1 Functional goals

The pipeline must support:

- build and deploy of multiple application components
- per-environment deployment targeting
- manual and automatic execution modes
- post-deploy health probing
- automatic rollback on failed probe
- manual rollback using explicit ARN, manifest history, or SSM fallback
- post-rollback recovery verification
- optional database seeding
- artifact promotion from lower environment to production
- deployment state persistence for reliable rollback
- auditable deployment history

### 1.2 Non-functional goals

The pipeline should:

- avoid "latest minus one" rollback guesswork
- separate trusted rollback pointers from historical deployment records
- avoid coupling deployment state to Terraform state
- keep job-level orchestration distinct from low-level cloud mechanics
- support reuse across projects and CI platforms
- prefer explicit contracts over implicit step coupling
- remain testable in lower environments before production rollout

---

## 2. Deployment Model

### 2.1 Infrastructure bootstrap model

Terraform bootstraps ECS services and related infrastructure, but runtime application revisions are created by CI/CD.

That means:

- Terraform is not the source of truth for deployed application revisions
- ECS task definition revisions are created dynamically by CI/CD
- rollback cannot rely on Terraform state
- rollback must rely on deployment-aware operational state

### 2.2 Source of truth model

The pipeline uses three complementary state stores:

1. ECS
- stores task definition revision history
- acts as the canonical revision ledger for deployed runtime definitions

2. SSM Parameter Store
- stores trusted deployment pointers
- used for `current` and `last-known-good` task definition ARNs
- optimized for rollback target lookup, not full history

3. S3
- stores deployment manifests
- acts as the auditable history of successful deployments, failures, rollbacks, rollback verification, seeding, and promotions

This split is intentional:

- ECS = revision store
- SSM = trusted pointer store
- S3 = audit/history store

---

## 3. Pipeline Stages

The logical pipeline has the following stages.

### 3.1 Detect changes

Purpose:
- determine which deployable components changed
- determine which environments should be targeted
- avoid triggering deployments for workflow-only edits during push events

Rules:
- on push, deploy only when monitored application paths change
- on manual dispatch, deploy based on explicit user inputs
- manual rollback should bypass deploy matrix creation entirely

Push semantics:
- push events should compare the new commit against the immediately preceding pushed commit
- they must not compare the branch against `main`
- special zero-SHA events must be handled explicitly

### 3.2 Deploy service

Purpose:
- resolve the image to deploy
- register a new ECS task definition revision
- update the ECS service to the new revision
- persist deploy metadata for downstream jobs

Deploy result is not considered final success until post-deploy probe passes.

### 3.3 Probe deployment

Purpose:
- validate the newly deployed surface
- capture health result, logs, and reason
- update trusted pointers only on success
- persist success or failure manifests

### 3.4 Automatic rollback

Purpose:
- restore the service to the trusted last-known-good task definition ARN after a failed deployment probe
- write rollback manifests
- reset current/last-known-good pointers back to the recovery target

### 3.5 Rollback verification probe

Purpose:
- verify that rollback actually restored healthy service behavior
- treat rollback as a recovery deployment, not a fire-and-forget ECS update
- not advance deployment pointers during verification

### 3.6 Manual rollback

Purpose:
- allow operator-initiated rollback based on:
  1. explicit task definition ARN
  2. manifest record
  3. SSM fallback

### 3.7 Manual rollback verification probe

Purpose:
- verify that the manually selected rollback target is healthy
- use the same probe mechanics as deployment probe
- avoid advancing pointers during recovery verification

### 3.8 Database seeding

Purpose:
- run a one-off task for database seeding
- capture success/failure, logs, and manifests
- keep seeding auditable as an operational action separate from main deploy success

### 3.9 Promotion

Purpose:
- promote an already validated image from lower environment to production region/repository
- reuse deployment workflow for production rollout instead of rebuilding for production

---

## 4. Reuse Boundary Model

The pipeline is intentionally split into:

- composite actions
- reusable workflows
- top-level orchestration workflows

### 4.1 What stays action-level

Actions encapsulate repeated cloud mechanics.

They should remain small, operational, and platform-portable in concept.

Current action inventory:

- `aws-fetch-network-ids`
- `deployment-manifest-write`
- `deployment-manifest-write-batch`
- `deployment-pointer-read`
- `deployment-pointer-write`
- `deployment-pointer-write-batch`
- `ecr-fetch-image`
- `ecs-build-push-image`
- `ecs-download-task-definition`
- `ecs-prepare-task-definition`
- `ecs-rollback-service`
- `ecs-run-task`
- `ecs-run-task-awsvpc`
- `ecs-wait-service-stable`
- `ecs-wait-task-result`

Action responsibilities:

- image build/push/fetch
- task definition download/render/register
- ECS task and service execution
- ECS wait and result inspection
- pointer read/write
- manifest write
- network ID lookup where needed

### 4.2 What stays workflow-level

Reusable workflows own multi-step orchestration with job-level semantics.

Current reusable workflows:

- `reusable-deploy-service.yml`
- `reusable-probe-environment.yml`
- `reusable-auto-rollback.yml`
- `reusable-manual-rollback.yml`
- `reusable-seed-database.yml`

Workflow responsibilities:

- environment binding
- approval boundaries
- job-level orchestration
- artifact coordination
- state transitions
- success/failure branching
- deployment/rollback/seeding lifecycle decisions

### 4.3 What stays top-level

Top-level workflows should only own:

- trigger definitions
- change detection
- matrix construction
- workflow routing
- policy decisions such as production gating or promotion invocation

Current top-level workflows:

- `deploy.yml`
- `promotion.yml`

---

## 5. Contract Conventions

### 5.1 Workflow/action contracts

Workflow and action inputs/outputs use `snake_case`.

Examples:

- `aws_account_id`
- `manifest_bucket`
- `task_definition_arn`
- `probe_status`
- `rollback_target_task_definition_arn`

Reason:
- shell-friendly
- consistent with GitHub Actions expression usage
- easier to read in CI wiring

### 5.2 JSON artifacts

JSON deployment metadata and manifest payloads use `camelCase`.

Examples:

- `taskDefinitionArn`
- `previousTaskDefinitionArn`
- `imageUri`
- `commitSha`
- `workflowRunId`

Reason:
- more natural for JavaScript consumers
- better aligned with future API or parser usage
- closer to AWS JSON conventions

### 5.3 Compatibility rule

Readers should tolerate both old and new field styles during migration windows.

This applies especially to:

- rollback reading historical manifests
- promotion reading lower-environment manifests
- pointer batch update actions reading older deploy metadata artifacts

---

## 6. Deployment Metadata Contract

Deployment metadata is written during the deploy stage and shared with downstream stages through artifacts.

It is not the long-term audit source of truth. It is a workflow-local contract used by later jobs in the same delivery chain.

### 6.1 Required metadata fields

A deployment metadata JSON record should contain at least:

```json
{
  "component": "frontend",
  "environment": "dev",
  "cluster": "project-cluster-dev",
  "service": "frontend-service",
  "previousTaskDefinitionArn": "arn:aws:ecs:...",
  "newTaskDefinitionArn": "arn:aws:ecs:...",
  "imageUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/project-frontend-repo-dev:abcdef",
  "commitSha": "abcdef123456",
  "workflowRunId": "123456789"
}
```

### 6.2 Why metadata exists

Metadata exists so later jobs do not need to rediscover mutable runtime state from ECS after the fact.

It allows:

- probe to know what was just deployed
- rollback to know what failed
- manifests to be written accurately
- promotion to consume validated artifact identity

---

## 7. Manifest Contract

Manifests are the durable audit records stored in S3.

### 7.1 Required manifest fields

A manifest should include at least:

```json
{
  "project": "project-name",
  "environment": "dev",
  "component": "frontend",
  "cluster": "project-cluster-dev",
  "service": "frontend-service",
  "taskDefinitionArn": "arn:aws:ecs:...",
  "previousTaskDefinitionArn": "arn:aws:ecs:...",
  "imageUri": "123456789012.dkr.ecr.us-east-1.amazonaws.com/project-frontend-repo-dev:abcdef",
  "commitSha": "abcdef123456",
  "workflowRunId": "123456789",
  "workflowName": "Build, Push, and Deploy to ECS",
  "deployedBy": "github-actor",
  "deployedAt": "2026-04-08T10:00:00Z",
  "status": "successful",
  "reason": "Probe passed"
}
```

### 7.2 Manifest categories

The system should write manifests for:

- deployment success
- deployment failure
- automatic rollback
- manual rollback
- rollback verification success
- rollback verification failure
- seeding success
- seeding failure
- promotion events

### 7.3 Manifest pathing

Suggested layout:

```text
<project>/deployments/<environment>/<component>/successful/
<project>/deployments/<environment>/<component>/failed/
<project>/deployments/<environment>/<component>/rollback/
<project>/rollback-verifications/<environment>/<component>/successful/
<project>/rollback-verifications/<environment>/<component>/failed/
<project>/deployments/<environment>/database-seeder/successful/
<project>/deployments/<environment>/database-seeder/failed/
<project>/promotions/prod/<component>/
```

The exact path can vary by platform, but the taxonomy should remain stable.

---

## 8. Trusted Pointer Model

### 8.1 SSM parameters

For each component/environment pair, store:

- `current-task-definition-arn`
- `last-known-good-task-definition-arn`

Example path:

```text
/<project>/<environment>/<component>/current-task-definition-arn
/<project>/<environment>/<component>/last-known-good-task-definition-arn
```

### 8.2 Pointer update rules

On successful deployment probe:
- update `current`
- update `last-known-good`

On failed deployment probe:
- do not advance pointers

On automatic rollback:
- set `current` to rollback target
- reset `last-known-good` to rollback target

On manual rollback:
- set `current` to chosen rollback target
- set `last-known-good` to chosen rollback target

On rollback verification probe:
- do not advance pointers

### 8.3 Why pointer updates are restricted

A successful recovery verification is not the same thing as promoting a new revision.

Deployment probe can promote.
Rollback verification can only confirm recovery.

---

## 9. Automatic Rollback Logic

### 9.1 Trigger condition

Automatic rollback should trigger when:

- deploy occurred
- deployment probe failed
- last-known-good pointer exists

### 9.2 Rollback target resolution

Automatic rollback target is:

- `last-known-good-task-definition-arn` from SSM

Never use:
- latest minus one
- implicit ECS ordering guesses
- Terraform state as deployed revision source

### 9.3 Rollback execution sequence

1. read deployment metadata
2. read last-known-good pointer
3. validate pointer exists
4. update ECS service to rollback target
5. reset deployment pointers
6. write rollback manifest
7. run rollback verification probe

### 9.4 Rollback verification sequence

1. run the same probe workflow against the environment
2. disable pointer updates
3. write rollback verification manifests
4. fail the overall workflow if rollback verification fails

---

## 10. Manual Rollback Logic

### 10.1 Manual rollback target resolution order

Manual rollback must resolve in this order:

1. explicit task definition ARN
2. selected manifest record
3. SSM last-known-good fallback

### 10.2 Manual rollback verification

Manual rollback should also be verified by probe after service update succeeds.

The verification probe must:

- not advance pointers
- write separate rollback verification manifests

---

## 11. Probe Logic

### 11.1 Probe purpose

The same probe implementation should support two purposes:

- deployment validation
- rollback recovery verification

### 11.2 Probe invariants

The same health signal should be used for both purposes:

- register probe task definition
- run probe task in target networking
- wait for stop
- inspect exit code, stopped reason, container reason
- collect logs

### 11.3 Probe differences by purpose

#### Deployment probe
- may update deployment pointers on success
- writes deployment success/failure manifests

#### Rollback verification probe
- must not update deployment pointers
- writes rollback verification success/failure manifests

---

## 12. Seeding Logic

### 12.1 Seeding role

Database seeding is operationally separate from normal application deploy success.

Seeding should:

- build or fetch its own image
- register its own task definition
- run as one-off task
- capture logs and exit status
- write success/failure manifests

### 12.2 Failure policy

Seeding may fail after manifest generation, but the failure should still surface in CI.

That means:

1. run seeder
2. collect result
3. write seeding manifest
4. fail workflow if exit code is non-zero

---

## 13. Promotion Model

### 13.1 Promotion purpose

Production should not rebuild images independently if the intention is to promote a tested lower-environment artifact.

Promotion should:

- read a successful lower-environment manifest
- extract the exact source image URI
- copy the approved image into the production-region ECR repository
- write a promotion manifest
- trigger production deploy using the promoted image from production ECR

### 13.2 Promotion source of truth

Promotion source should be:

- a successful manifest from lower environment

Not:
- generic latest image from source repo without validation context

### 13.3 Production deploy after promotion

Production deploy should reuse the normal deployment workflow and fetch the promoted image from the production repository.

### 13.4 Approval boundary

Production approval should occur before:

- image promotion into production ECR
- triggering production deployment

---

## 14. Change Detection Model

### 14.1 Push-based execution

Push events should only auto-run deployment logic when deployable app paths change.

Monitored paths in current design:

- `lirw-three-tier/frontend/**`
- `lirw-three-tier/backend/**`
- `lirw-three-tier/probe/**`

Workflow-only edits should not auto-run deploys.

### 14.2 Manual execution

Manual dispatch should remain available for:

- workflow testing
- rollback testing
- production deploys
- seeding
- targeted environment runs

### 14.3 Zero-SHA handling

If push event `before` SHA is all zeroes:

1. use `HEAD^` when available
2. if not available, assume monitored components changed

Do not fall back to `main` comparison.

Reason:
- comparing branch against main causes long-lived branches to appear permanently changed

---

## 15. Network Mode Model

Deploy and task execution must support both:

- non-`awsvpc`
- `awsvpc`

### 15.1 Non-awsvpc mode

Used when ECS service/task networking does not require subnet and security group injection at run time.

### 15.2 awsvpc mode

Must support:

- service updates with network configuration
- one-off task runs with network configuration
- optional internal lookup of subnet IDs and security groups from environment-specific names/tags

The current design places awsvpc-specific lookup inside the awsvpc execution action.

---

## 16. Environment Configuration Model

Environment-specific behavior should come from environment-scoped CI variables rather than hardcoded YAML branching.

Examples:

- `AWS_REGION`
- `ACCOUNT_ID`
- `ENV_VAR`
- `PROJECT_NAME`
- `DEPLOYMENT_MANIFEST_BUCKET`
- `SERVICE_NETWORK_MODE`
- `SERVICE_SECURITY_GROUP_NAME`
- `SERVICE_SUBNET_TAG_VALUES`
- `SERVICE_ASSIGN_PUBLIC_IP`
- `SEEDER_NETWORK_MODE`
- `SEEDER_SECURITY_GROUP_NAME`
- `SEEDER_SUBNET_TAG_VALUES`
- `SEEDER_ASSIGN_PUBLIC_IP`

This lets dev and prod differ without requiring workflow edits.

---

## 17. Current GitHub Actions Mapping

### 17.1 Top-level workflows

- `deploy.yml`
  - detects changes
  - constructs matrix
  - calls reusable workflows
  - owns trigger and routing logic

- `promotion.yml`
  - performs approval-gated image promotion
  - triggers production deployment workflow

### 17.2 Reusable workflows

- `reusable-deploy-service.yml`
- `reusable-probe-environment.yml`
- `reusable-auto-rollback.yml`
- `reusable-manual-rollback.yml`
- `reusable-seed-database.yml`

### 17.3 Action layer

Cloud mechanics are encapsulated in `.github/actions/*`.

---

## 18. GitLab CI Replication Guidance

### 18.1 Mapping concepts

GitHub Actions concept -> GitLab CI concept

- composite action -> shell/function template or included YAML template job block
- reusable workflow -> hidden job template or child pipeline
- workflow_call -> included CI template or child pipeline trigger
- artifact upload/download -> `artifacts`, `dependencies`, `needs:artifacts`
- environment-scoped vars -> GitLab environments and scoped variables
- manual dispatch -> `when: manual`
- approval gate -> protected environments / manual approval jobs

### 18.2 Recommended GitLab structure

Suggested stages:

```text
stages:
  - detect
  - deploy
  - probe
  - rollback
  - verify_rollback
  - seed
  - promote
```

Suggested reusable templates:

- `.deploy_service_template`
- `.probe_environment_template`
- `.auto_rollback_template`
- `.manual_rollback_template`
- `.seed_database_template`

Use child pipelines only when job graph complexity or environment gating makes it helpful. Otherwise prefer hidden job templates plus `extends`.

### 18.3 GitLab state handling

Keep the same cloud state design:

- SSM for pointers
- S3 for manifests
- ECS for revisions

Do not replace this with GitLab-only artifacts as long-term rollback state.

---

## 19. CircleCI Replication Guidance

### 19.1 Mapping concepts

GitHub Actions concept -> CircleCI concept

- composite action -> command / reusable orb command / shell script
- reusable workflow -> reusable commands + jobs + parameterized workflow
- workflow_call -> parameterized workflows or dynamic config
- artifacts -> CircleCI artifacts and workspaces
- environment vars -> contexts and project/environment variables
- manual dispatch -> API-triggered pipeline with parameters
- approval gate -> `type: approval`

### 19.2 Recommended CircleCI structure

Suggested jobs:

- `detect_changes`
- `deploy_service`
- `probe_environment`
- `auto_rollback`
- `verify_rollback_recovery`
- `manual_rollback`
- `verify_manual_rollback_recovery`
- `seed_database`
- `promote_image`

Use CircleCI pipeline parameters for:

- action type
- target environment
- build vs fetch selection
- rollback target override
- seeding toggle

### 19.3 Workspaces and artifacts

Use workspaces for handoff of deployment metadata within a pipeline, but keep S3 manifests as the durable cross-run history.

---

## 20. Failure Handling Rules

### 20.1 Deployment failure

If deployment probe fails:

- write failure manifests
- execute automatic rollback
- verify rollback recovery
- fail workflow if recovery verification fails

### 20.2 Rollback failure

If rollback target cannot be resolved or rollback execution fails:

- fail workflow immediately
- write as much context as possible to job summary and manifests

### 20.3 Verification failure

If rollback verification fails:

- fail workflow
- write rollback verification failure manifest
- clearly distinguish this from initial deploy failure

### 20.4 Seeding failure

If seeding task exits non-zero:

- write seeding failure manifest
- fail workflow afterward

---

## 21. Security and IAM Requirements

The deployment role must support:

- ECR push/pull operations
- ECS describe/register/update/run/stop operations
- IAM pass role where required
- EC2 describe for networking lookups
- CloudWatch Logs read for probe/seeder log collection
- SSM get/put for deployment pointers
- S3 get/put/list for manifest storage

The CI platform should use short-lived identity where possible:

- GitHub OIDC
- GitLab OIDC or cloud IAM federation where available
- CircleCI OIDC or equivalent short-lived role assumption

Avoid long-lived static cloud keys when possible.

---

## 22. Testing Strategy

### 22.1 Required validation scenarios

At minimum, validate:

1. Normal dev deploy success
2. Dev deploy probe failure -> automatic rollback -> rollback verification success
3. Dev deploy probe failure -> automatic rollback -> rollback verification failure
4. Manual rollback by explicit ARN
5. Manual rollback by manifest key
6. Manual rollback by SSM fallback
7. Seeding success
8. Seeding failure
9. Promotion from dev to prod repository
10. Production deploy using promoted image
11. First push / zero-SHA path detection behavior

### 22.2 Observability expectations

Each run should surface:

- job summaries
- artifact names
- manifest upload results
- probe and seeder logs
- rollback reasons
- promotion source and target image URIs

---

## 23. Replication Checklist

To reproduce this pipeline in another CI platform, implement the following in order:

1. ECS/ECR deployment primitives
2. SSM pointer read/write
3. S3 manifest persistence
4. deploy metadata handoff between stages
5. deployment probe
6. automatic rollback
7. rollback verification probe
8. manual rollback resolution order
9. seeding task support
10. promotion flow
11. environment-scoped configuration
12. approval boundaries for production
13. push change detection semantics
14. zero-SHA fallback handling

---

## 24. Design Principles Summary

This pipeline is built around a few core principles:

- deployment state is operational state, not Terraform state
- rollback targets must be explicit and trusted
- health verification is required after both deploy and rollback
- history and pointers are different responsibilities
- low-level cloud mechanics should be reusable independently of orchestration
- job-level orchestration should be reusable independently of top-level routing
- workflow experimentation should not automatically trigger deployments
- JSON should remain friendly to future programmatic consumers

This specification should be treated as the canonical blueprint for implementing equivalent pipelines in other CI systems.

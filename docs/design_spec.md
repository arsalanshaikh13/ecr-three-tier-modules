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

Running-version note:
- deploy image strategy is caller-owned at the top-level orchestration workflow
- the reusable deploy workflow receives explicit `build_image` and `fetch_image` inputs
- the reusable deploy workflow resolves environment-scoped values inside its bound job, not in the caller

### 3.3 Probe deployment

Purpose:
- validate the newly deployed surface
- capture health result, logs, and reason
- update trusted pointers only on success
- persist success or failure manifests

Running-version note:
- normal deployment probe uses a fetch-first image strategy
- it first tries to reuse the latest existing probe image from ECR
- it only builds the probe image if fetch does not find one
- rollback verification probe is fetch-only and does not rebuild the probe image
- probe execution mode is now flexible and can run as:
  - `FARGATE + awsvpc`
  - `EC2 + awsvpc`
  - `EC2 + non-awsvpc`

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

Important running-version rule:
- the awsvpc execution action owns awsvpc-specific network lookup and network-configuration assembly
- workflows should describe network intent, not rebuild subnet/security-group lookup logic inline
- ECS execution actions should also receive explicit region intent from reusable workflow callers
  even when the underlying CI environment already exports `AWS_REGION`
- the action layer should not silently depend on whichever AWS CLI default region happens to
  be present if the workflow can state region explicitly

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

Important running-version rule:
- reusable workflows should not hide deployment image policy defaults
- reusable workflows execute the caller's requested policy
- top-level workflows decide whether a run is build-only, fetch-only, or fetch-first/build-if-missing

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

### 5.4 Policy ownership rule

The running architecture uses the following policy boundary:

- top-level workflow owns policy
- reusable workflow owns job execution
- action owns operational mechanics

In practice this means top-level orchestration decides:

- `build_image`
- `fetch_image`
- target environments
- whether rollback verification should advance pointers

while reusable workflows do not silently invent image-strategy behavior on behalf of the caller.

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

Running-version note:
- deployment metadata is written once during deploy and passed forward as workflow-local artifacts
- downstream jobs consume this metadata instead of inferring deployment state from mutable ECS service state

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

Running-version note:
- this rule is enforced by giving the probe workflow an explicit `update_pointers_on_success` input
- normal deployment probe passes `true`
- rollback verification passes `false`

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

Running-version note:
- probe task definition preparation reuses the shared `ecs-prepare-task-definition` action
- ECS task waiting/log extraction reuses the shared `ecs-wait-task-result` action

### 11.3 Probe differences by purpose

#### Deployment probe
- may update deployment pointers on success
- writes deployment success/failure manifests

#### Rollback verification probe
- must not update deployment pointers
- writes rollback verification success/failure manifests

### 11.4 Probe image resolution strategy

The running design uses explicit probe image strategy rather than implicit defaults.

Supported modes:

- build-only
- fetch-only
- fetch-first with build fallback

Current operating choice:

- normal deploy probe: fetch-first with build fallback
- rollback verification probe: fetch-only
- operational default probe runtime: `FARGATE + awsvpc`

Reason:
- the first probe run should be able to seed ECR automatically
- later probe runs should reuse the already-published probe image when possible
- rollback verification should be fast and should not mutate probe artifacts
- even though probe supports EC2 execution modes, real runs showed that Fargate probe tasks
  stopped faster and behaved better as a short-lived verification surface

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

Running-version note:
- seeding follows the same caller-owned image policy model as deploy and probe
- the top-level workflow currently chooses build-only for seeding
- the reusable seeding workflow accepts explicit `build_image` and `fetch_image` inputs so this can be changed without editing seeding internals

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

Running-version note:
- the awsvpc action is also responsible for constructing valid AWS CLI network JSON
- JSON should be assembled structurally rather than by fragile shell string interpolation

### 15.3 Execution flexibility principle

The running design intentionally allows deploy, probe, and seeding flows to support all ECS runtime/network combinations that the target environment can support.

Supported combinations:

- `EC2 + non-awsvpc`
- `EC2 + awsvpc`
- `FARGATE + awsvpc`

This is intentional for several reasons:

- it removes artificial capability differences between deploy, probe, and seeding
- it reflects ECS's real separation of launch type from network mode
- it makes the reusable workflows more portable across projects and migration phases
- it lets environments differ by configuration instead of by workflow rewrites

Important design interpretation:

- non-awsvpc execution belongs in the generic ECS run action
- awsvpc execution belongs in the awsvpc-specific ECS run action
- reusable workflows choose between those actions based on execution mode
- top-level orchestration or environment configuration decides which mode is desired

### 15.4 Operator defaults should be concrete, not abstract

The running design now prefers concrete workflow-dispatch defaults such as:

- `EC2` or `FARGATE`
- `awsvpc` or `non-awsvpc`

and intentionally avoids an `auto` dispatch mode.

Reason:
- abstract runtime defaults made manual testing harder to reason about
- concrete choices are easier to review and less likely to hide unintended behavior

Interpretation:
- top-level defaults should still be overrideable per job
- but the operator-facing contract should speak in explicit ECS terms

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
- `PROBE_NETWORK_MODE`
- `PROBE_LAUNCH_TYPE`
- `PROBE_SECURITY_GROUP_NAME`
- `PROBE_SUBNET_TAG_VALUES`
- `PROBE_ASSIGN_PUBLIC_IP`

This lets dev and prod differ without requiring workflow edits.

Critical running-version rule:
- environment-scoped values must be resolved inside reusable workflow jobs that are bound with:

```yaml
environment: ${{ inputs.environment }}
```

- environment-scoped values should not be eagerly resolved in the top-level caller when that would risk prod jobs inheriting dev values

Additional running-version note:
- when reusable workflows call lower-level ECS runner actions, they should pass the resolved
  region explicitly to the action boundary as part of the environment-bound execution contract
- this matters most in multi-region dev/prod setups where ambient CLI defaults are too implicit

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

### 17.4 Running behavior details

The running GitHub Actions implementation now also includes:

- caller-owned image strategy for deploy, probe, and seeding
- environment-scoped variable resolution inside reusable workflows
- explicit region propagation from reusable workflows into ECS runner actions
- fetch-first probe behavior with soft-missing ECR fetch
- awsvpc-internal network lookup and JSON construction
- pragmatic awsvpc fallback defaults in some reusable workflows when network inputs are omitted
- shared ECS task-result waiting across probe and seeding
- rollback verification as a distinct post-rollback probe stage
- probe execution flexibility across EC2/Fargate and awsvpc/non-awsvpc modes
- probe jobs operationally pinned to `FARGATE + awsvpc` in top-level orchestration even though
  broader ECS execution flexibility remains supported

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

---

## 25. Drift from the Original Specification

The architecture did not drift because the original design was wrong at a high level. It drifted because real execution exposed where the original specification was too abstract or not strict enough at the operating boundary.

### 25.1 Drift: image policy moved fully to the caller

Original tendency:
- some reusable workflows carried image-strategy defaults internally

Current running design:
- top-level orchestration explicitly passes `build_image` and `fetch_image`

Why this drift happened:
- hidden defaults made behavior harder to predict
- different workflows were becoming inconsistent
- rollout intent is easier to review when it is visible in one top-level file

### 25.2 Drift: environment var resolution moved inward

Original tendency:
- environment-specific values could be passed from the caller

Current running design:
- reusable workflows resolve environment-scoped vars inside jobs bound to the target environment

Why this drift happened:
- prod jobs were able to accidentally inherit dev-scoped values when vars were resolved too early
- multi-environment correctness mattered more than keeping the caller superficially thinner

### 25.3 Drift: probe changed from build-oriented to fetch-first

Original tendency:
- probe could be described as just another build-and-run path

Current running design:
- normal probe is fetch-first with build fallback
- rollback verification probe is fetch-only

Why this drift happened:
- rebuilding probe every time was redundant
- only the first probe needs to seed ECR if the repository is empty
- rollback verification should validate recovery, not recreate probe artifacts

### 25.4 Drift: awsvpc lookup responsibility moved deeper into actions

Original tendency:
- workflows could own subnet/security-group lookup logic

Current running design:
- awsvpc lookup and network JSON assembly live inside the awsvpc execution action

Why this drift happened:
- awsvpc-specific plumbing was repeating across workflows
- shell-built JSON was brittle and caused runtime AWS CLI failures
- the action boundary became more honest once it owned the full awsvpc execution concern

### 25.5 Drift: rollback verification became a first-class stage

Original tendency:
- rollback could be treated mainly as an ECS corrective update

Current running design:
- rollback is followed by explicit recovery verification probe

Why this drift happened:
- a successful rollback command does not prove a healthy recovered application
- operational confidence required validating rollback, not merely performing it

### 25.6 Drift: probe moved from Fargate-only assumption to full ECS execution flexibility

Original tendency:
- probe was implicitly treated as a Fargate + awsvpc-only operation

Current running design:
- probe can run as:
  - `FARGATE + awsvpc`
  - `EC2 + awsvpc`
  - `EC2 + non-awsvpc`

Why this drift happened:
- seeding and deploy already had broader execution flexibility
- probe should not be artificially less capable than the other execution workflows
- future projects and environments may differ in runtime model
- keeping the capability symmetric across jobs makes the architecture easier to reuse and reason about

### 25.7 Interpretation of the drift

These changes should be treated as specification refinement, not architecture drift in the negative sense.

They show that the correct long-term design is:

- stricter about policy ownership
- stricter about environment scoping
- more verification-heavy
- less tolerant of hidden defaults
- more honest about where cloud-specific complexity really belongs

### 25.8 Drift: region became an explicit action-boundary concern

Original tendency:
- region correctness was mostly implied by environment-scoped AWS credential setup

Current running design:
- reusable workflows pass region explicitly into ECS runner actions
- the action layer still supports env fallback, but the caller now makes region intent visible

Why this drift happened:
- real multi-region dev/prod execution exposed that ambient CLI defaults were too implicit
- ECS runner behavior needed to remain deterministic even as environment layouts diverged

### 25.9 Drift: dispatch defaults became concrete and operator-facing

Original tendency:
- workflow-level runtime defaults could remain abstract, including earlier `auto` behavior

Current running design:
- dispatch-level runtime defaults are concrete:
  - `EC2` or `FARGATE`
  - `awsvpc` or `non-awsvpc`

Why this drift happened:
- abstract defaults made test runs harder to understand
- explicit choices reduced ambiguity during manual operations

### 25.10 Drift: probe remained capability-flexible but operationally pinned

Original tendency:
- once probe gained ECS execution flexibility, the design could suggest that all runtime
  combinations were equally desirable in day-to-day operation

Current running design:
- probe still supports:
  - `FARGATE + awsvpc`
  - `EC2 + awsvpc`
  - `EC2 + non-awsvpc`
- but top-level orchestration intentionally pins probe jobs to `FARGATE + awsvpc`

Why this drift happened:
- real runs showed EC2 probe tasks were slower to stop
- probe is a verification workload, so fast and predictable lifecycle mattered more than
  mirroring every possible service runtime shape

### 25.11 Drift: temporary awsvpc fallback defaults became part of the running model

Original tendency:
- explicit inputs and environment-scoped vars were the preferred source of awsvpc network config

Current running design:
- some reusable workflows temporarily derive awsvpc defaults when inputs are empty

Why this drift happened:
- the project needed to remain runnable while network input standardization was still in progress
- strict failure on missing awsvpc inputs would have slowed validation of the broader architecture

Interpretation:
- this is a pragmatic running-version behavior, not necessarily the final desired end-state

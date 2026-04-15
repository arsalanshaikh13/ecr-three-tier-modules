# Workflow Architecture Change Log

## Purpose

This document summarizes the workflow and action changes made during the afternoon refactor session that took the CI/CD pipeline from a mostly inline GitHub Actions workflow to a reusable-workflow and composite-action architecture that now runs with a much cleaner separation of concerns.

The goal of the refactor was not only to reduce copy-paste, but to make the deployment system:

- easier to reason about
- safer across `dev` and `prod`
- easier to port to other CI systems later
- easier to debug when deployment, probe, rollback, or seeding fails

---

## High-Level Outcome

The pipeline now follows a much clearer layering model:

- `deploy.yml` owns orchestration and policy
- reusable workflows own job-level execution flows
- composite actions own repeated operational mechanics
- SSM stores last-known-good deployment pointers
- S3 stores immutable audit manifests
- ECS task/service operations are reused through shared actions instead of copied shell blocks

This is the main reason the architecture became stable and reusable rather than just shorter.

---

## Main Design Decisions

## 1. Split Action-Level Mechanics from Workflow-Level Orchestration

We formalized the boundary:

- **Composite actions** for repeated step bundles
- **Reusable workflows** for full job orchestration

### Why

Earlier, repeated shell fragments were spread across `deploy`, `probe`, `rollback`, and `seed-database`. Even after introducing some actions, the workflow still repeated job-sized patterns.

That made the pipeline:

- harder to extend
- harder to test
- harder to port to GitLab or CircleCI

### Final rule

- Actions handle mechanics such as:
  - build/push image
  - fetch latest image from ECR
  - prepare/register ECS task definition
  - run ECS task
  - update ECS service
  - wait for ECS task result
  - write manifests
  - write deployment pointers

- Reusable workflows handle orchestration such as:
  - deploy service
  - probe environment
  - auto rollback
  - manual rollback
  - seed database

---

## 2. Convert Large Inline Jobs into Reusable Workflows

We extracted the main orchestration units into reusable workflows:

- `.github/workflows/reusable-deploy-service.yml`
- `.github/workflows/reusable-probe-environment.yml`
- `.github/workflows/reusable-auto-rollback.yml`
- `.github/workflows/reusable-manual-rollback.yml`
- `.github/workflows/reusable-seed-database.yml`

### Why

This let `deploy.yml` become a routing/orchestration entrypoint instead of a monolith containing every cloud operation inline.

### Benefit

The top-level workflow is now responsible for:

- event handling
- path detection
- matrix generation
- choosing environments
- choosing image strategy
- deciding whether to deploy, probe, seed, or rollback

while each reusable workflow focuses on one bounded operational flow.

---

## 3. Extract Shared ECS Task-Definition Preparation

We created a shared action:

- `.github/actions/ecs-prepare-task-definition/action.yml`

It now owns the common pre-registration flow used by deploy, probe, and seeding:

- ECR login
- image resolution
- ECS task definition download
- task definition render
- task definition registration

### Why

Deploy, probe, and seeding all repeated the same logic until task definition registration. That was the right abstraction boundary for shared mechanics.

### Benefit

Each caller now only owns what happens **after** task definition registration:

- deploy updates a service
- probe runs a one-off task and checks health
- seeding runs a one-off task and checks seeder result

---

## 4. Make ECS Runner Actions Flexible for Both Task and Service Mode

We generalized:

- `.github/actions/ecs-run-task/action.yml`
- `.github/actions/ecs-run-task-awsvpc/action.yml`

Both can now support:

- one-off task execution
- ECS service update execution

### Why

Earlier, service updates were partly inline while task runs used actions. That created an awkward split.

### Design decision

We introduced the idea that these actions represent an ECS execution boundary:

- `task` mode = run a one-off ECS task
- `service` mode = update an ECS service to a new task definition

### Benefit

This reduced inline AWS CLI usage inside reusable workflows and kept ECS execution behavior in one reusable place.

---

## 5. Move awsvpc-Specific Network Lookup into the awsvpc Action

We moved subnet/security-group lookup into:

- `.github/actions/ecs-run-task-awsvpc/action.yml`

### Why

Only awsvpc execution needs subnet and security-group resolution. Keeping this outside the action forced the workflows to carry too much implementation detail.

### Design decision

The awsvpc action now accepts either:

- direct IDs
- or lookup inputs such as SG name and subnet tag values

and resolves network configuration internally.

### Benefit

Reusable workflows now describe desired network intent rather than reconstructing AWS lookup plumbing every time.

---

## 6. Fix awsvpc Network JSON Construction

We fixed a bug in awsvpc task/service execution where subnet arrays were being interpolated into JSON without proper quoting.

### Problem

AWS rejected `--network-configuration` because the generated JSON looked like:

```json
{"subnets":[subnet-abc,subnet-def]}
```

instead of:

```json
{"subnets":["subnet-abc","subnet-def"]}
```

### Fix

We changed the awsvpc action to build JSON using `jq`.

### Benefit

The awsvpc runner now produces valid AWS CLI JSON consistently and no longer depends on fragile shell string interpolation.

---

## 7. Extract Shared ECS Task Result Waiting and Inspection

We created:

- `.github/actions/ecs-wait-task-result/action.yml`

This action now centralizes:

- wait for ECS task to stop
- exit code extraction
- stopped reason extraction
- combined result reason
- optional CloudWatch log retrieval

### Why

Probe and seeding both needed the same “wait and inspect ECS task result” behavior.

### Benefit

Failure handling and log surfacing are now consistent between probe and seeding.

---

## 8. Add Rollback Verification Probe

We added rollback verification as a separate post-rollback probe path.

### Why

Previously, rollback success meant:

- rollback command executed

but did **not** mean:

- rolled-back application is actually healthy

That left rollback behavior untested in practice.

### Design decision

We reused the same probe workflow after rollback, but added guardrails:

- rollback verification uses `probe_purpose: rollback_verification`
- rollback verification sets `update_pointers_on_success: false`

### Why this matters

Rollback verification should confirm recovery, not promote a new revision or rewrite last-known-good pointers.

### Benefit

Rollback is now treated as a recover-and-verify flow instead of a blindly trusted corrective action.

---

## 9. Make Probe Image Resolution Fetch-First

We changed probe behavior so it:

- fetches an existing probe image first
- builds only if no probe image exists

This required updates to:

- `.github/actions/ecr-fetch-image/action.yml`
- `.github/actions/ecs-prepare-task-definition/action.yml`
- `.github/workflows/reusable-probe-environment.yml`
- `.github/workflows/deploy.yml`

### Why

Normal probe runs do not need to rebuild the probe image every time. Only the first run should seed ECR if the repo is empty.

### Design decision

`ecr-fetch-image` now supports a soft-missing mode:

- `image_found=true/false`

and `ecs-prepare-task-definition` now supports:

- fetch first
- build only if fetch misses

### Final behavior

- normal probe: fetch-first, build-if-missing
- rollback verification probe: fetch-only
- forced rebuild remains possible by caller choice

### Benefit

Probe became:

- faster
- cheaper
- less noisy
- more deterministic

---

## 10. Move Image Strategy Decisions to the Caller

We cleaned up the architecture so `deploy.yml` owns image policy decisions for:

- deploy
- probe
- seed-database

### Why

Earlier, some image decisions were hidden inside reusable workflows while others were decided in the caller. That made the architecture inconsistent.

### Final rule

- caller owns policy:
  - `build_image`
  - `fetch_image`
- reusable workflow owns execution

### Benefit

This gives one place to inspect rollout intent and removes hidden defaults from reusable workflow behavior.

---

## 11. Resolve Environment-Specific Variables Inside Reusable Workflows

We fixed a multi-environment bug where prod jobs could accidentally resolve dev variables.

### Problem

When environment-scoped vars were passed from `deploy.yml`, GitHub could resolve them too early at the caller layer, causing prod execution with dev values.

Example failure:

- prod run
- but ECR repo resolved to `*-dev`

### Fix

We moved environment-scoped variable resolution into the reusable workflow jobs themselves, where the job is bound to:

```yaml
environment: ${{ inputs.environment }}
```

### Benefit

Now each reusable workflow resolves:

- `vars.ENV_VAR`
- `vars.AWS_REGION`
- `vars.ACCOUNT_ID`
- `vars.DEPLOYMENT_MANIFEST_BUCKET`

inside the correct environment scope.

This was one of the key changes that made multi-env execution reliable.

---

## 12. Improve Push Change Detection and Handle Zero-SHA Events

We changed path filtering behavior in `deploy.yml`.

### Problems solved

1. `dorny/paths-filter` was effectively comparing feature branch state to `main`
2. workflow file edits were unnecessarily triggering deploy logic
3. zero-SHA push events were causing brittle diff behavior

### Changes made

- push trigger restricted to deployable app paths:
  - `lirw-three-tier/frontend/**`
  - `lirw-three-tier/backend/**`
  - `lirw-three-tier/probe/**`
- `dorny/paths-filter` now compares:
  - `github.event.before`
  - `github.sha`
- zero-SHA fallback logic:
  - use parent commit if available
  - otherwise assume monitored surfaces changed

### Benefit

Push runs now reflect actual app changes in the push instead of long-lived branch drift against `main`.

---

## 13. Add Seeding Audit Manifests

We extended database seeding so it writes manifests too.

### Why

Seeding was operationally important but lacked the same audit trail as deployment and rollback.

### Changes

Seeding now writes:

- success manifests
- failure manifests

with:

- task definition ARN
- previous task definition ARN
- image URI
- environment
- timestamp
- commit SHA
- workflow metadata
- ECS result reason

### Benefit

Seeding is now auditable like the rest of the pipeline.

---

## 14. Standardize Naming Contracts

We tightened input and output naming across reusable workflows.

### Workflow contracts now follow a consistent style for:

- `environment`
- `project_name`
- `component`
- `build_image`
- `fetch_image`
- output names such as:
  - `task_definition_arn`
  - `previous_task_definition_arn`
  - `manifest_artifact_name`

### Why

Predictable contracts reduce cognitive load and make the workflows easier to reuse across projects.

---

## 15. Choose JSON-First Manifest Naming Strategy

We settled on:

- workflow/action contracts: `snake_case`
- JSON metadata/manifests: `camelCase`

### Why

JSON is more naturally consumed later by JavaScript tooling, while GitHub Actions contracts are more comfortable in `snake_case`.

### Benefit

This gives good ergonomics at both layers:

- shell/workflow contracts stay readable
- JSON artifacts stay friendly to JS parsing and downstream automation

---

## Files Added or Materially Introduced During the Refactor

### Reusable workflows

- `.github/workflows/reusable-deploy-service.yml`
- `.github/workflows/reusable-probe-environment.yml`
- `.github/workflows/reusable-auto-rollback.yml`
- `.github/workflows/reusable-manual-rollback.yml`
- `.github/workflows/reusable-seed-database.yml`

### Composite actions

- `.github/actions/ecs-prepare-task-definition/action.yml`
- `.github/actions/ecs-wait-task-result/action.yml`

### Architecture docs

- `.github/WORKFLOW_ARCHITECTURE.md`
- `design_spec.md`

---

## Why the Architecture Is Now Successfully Running

The architecture became stable not because of one isolated fix, but because several design problems were solved together:

### 1. Boundaries became explicit

- caller decides policy
- reusable workflow executes job flow
- action executes mechanics

### 2. Multi-environment resolution became correct

Environment-specific variables now resolve inside environment-bound jobs, which fixed prod/dev crossovers.

### 3. Repeated cloud logic stopped drifting

Core ECS/ECR/task-handling behavior now lives in shared actions instead of being reimplemented slightly differently in each job.

### 4. Verification improved

Deployments are probed.
Rollbacks are probed.
Seeding results are audited.

The system now validates more of what it assumes.

### 5. Change detection became intentional

Push runs now reflect deployable changes instead of branch-diff noise.

### 6. Manifest and metadata contracts became predictable

Downstream rollback, promotion, and debugging now have a stable contract to read from.

---

## Final Operating Model

### `deploy.yml`

Acts as the orchestration entrypoint:

- detect changes
- build matrices
- choose environments
- choose image strategy
- call reusable workflows

### Reusable workflows

Act as job-level execution units:

- deploy service
- probe environment
- rollback automatically
- rollback manually
- run database seeding

### Composite actions

Act as reusable mechanics:

- build or fetch image
- prepare task definition
- run ECS task/service
- wait for ECS task result
- write manifests and deployment pointers

---

## Practical Lessons from the Refactor

1. If repeated logic includes job-level concerns, it probably belongs in a reusable workflow, not another action.
2. If repeated logic stops at a clean operational boundary, it probably belongs in an action.
3. Environment-scoped variables should be resolved where the job is actually bound to the environment.
4. Rollback should be verified, not assumed.
5. Push-based change detection should compare push-to-push, not branch-to-main.
6. Hidden policy defaults inside reusable workflows make behavior harder to predict.
7. JSON and workflow contract naming can intentionally use different conventions if the boundary is explicit.

---

## Recommended Next Steps

- keep validating with real `dev` and `prod` runs
- keep new job behavior visible in `deploy.yml`
- avoid moving image policy back into reusable workflow defaults
- reuse the same action/workflow boundary when porting to GitLab CI or CircleCI
- extend documentation whenever a new orchestration unit is added

---

## Final Summary

The afternoon refactor succeeded because we did more than “deduplicate code.”

We:

- defined architectural boundaries
- corrected environment scoping
- centralized repeated mechanics
- made job orchestration reusable
- improved rollback verification
- improved manifesting and auditing
- clarified ownership of policy vs execution

That combination is what made the reusable workflow + action architecture not just cleaner, but operationally dependable.

# CircleCI-Focused Prompt for CI/CD Pipeline Architecture

Use this prompt when you want an LLM to generate the CircleCI version of the ECS-based CI/CD pipeline architecture implemented in this repository.

---

You are a senior platform engineer. Design a CircleCI pipeline that faithfully reproduces a reusable ECS-based CI/CD system currently implemented in GitHub Actions.

Your job is not to translate YAML literally. Your job is to recreate the same architecture, lifecycle, contracts, and operational behavior using CircleCI-native primitives.

## 1. Target Outcome

Produce a detailed, list-oriented architecture and implementation specification for a CircleCI system that supports:

1. multi-component ECS delivery
2. multi-environment delivery for at least `dev` and `prod`
3. multi-region AWS delivery where `dev` and `prod` may differ by region
4. deploy, probe, rollback, rollback verification, seeding, and promotion
5. reusable CircleCI jobs/commands/orbs or equivalent abstractions
6. environment-scoped configuration and approval boundaries

## 2. Source Architecture You Must Preserve

The CircleCI design must preserve these architectural truths:

1. Terraform bootstraps infrastructure, but CI/CD creates runtime ECS task definition revisions.
2. ECS is the task definition revision ledger.
3. SSM Parameter Store is the trusted deployment pointer store.
4. S3 is the durable deployment/rollback/seeding/promotion manifest store.
5. Deployment is not successful until probe passes.
6. Rollback is not successful until rollback verification passes.
7. Promotion uses a successful lower-environment manifest as its source of truth.

## 3. Required CircleCI Mapping

Map the original architecture into CircleCI-native constructs.

You must explicitly describe equivalents for:

1. top-level orchestration workflow
2. reusable workflows/templates
3. reusable actions or commands
4. matrix-style environment/component targeting
5. pipeline parameters
6. approval gates
7. artifact and workspace handoff
8. environment-scoped variables and contexts
9. dynamic config if needed

Recommended CircleCI building blocks to consider:

1. parameterized workflows
2. parameterized jobs
3. reusable commands
4. reusable executors
5. pipeline parameters
6. workspaces
7. artifacts
8. `type: approval`
9. contexts
10. dynamic configuration when justified

## 4. Required Pipeline Stages / Jobs

Design CircleCI jobs or logical groups for:

1. `detect_changes`
2. `deploy_service`
3. `probe_environment`
4. `auto_rollback`
5. `verify_rollback_recovery`
6. `manual_rollback`
7. `verify_manual_rollback_recovery`
8. `seed_database`
9. `promote_image`

For each one, specify:

1. purpose
2. required parameters
3. required environment variables or contexts
4. upstream dependencies
5. workspace/artifact inputs and outputs
6. failure behavior
7. ECS/SSM/S3 responsibilities

## 5. State and Artifact Rules

Preserve the state model exactly:

1. ECS = revision history
2. SSM = trusted pointers
3. S3 = durable manifests

Use CircleCI workspaces or artifacts only for workflow-local handoff such as deployment metadata.

Do not use workspaces/artifacts as the durable rollback history source.

## 6. Change Detection Rules

Preserve the same deploy-intent semantics:

1. push-based deployment should only trigger when deployable application paths change
2. workflow-only edits should not imply deploy intent
3. branch-vs-main drift must not be treated as deploy intent
4. zero-SHA or first-push-like edge cases must be handled explicitly
5. manual or API-triggered pipelines should remain the primary path for workflow testing and targeted runs

## 7. Environment and Region Rules

Preserve these correctness rules:

1. environment-scoped values must resolve inside the environment-bound job or command path
2. do not resolve prod/dev-sensitive values too early in parent orchestration
3. region must be explicit at the ECS action/command boundary
4. dev and prod may use different regions and ECR repositories

## 8. Runtime and Network Rules

The CircleCI design must support:

1. `EC2 + non-awsvpc`
2. `EC2 + awsvpc`
3. `FARGATE + awsvpc`

You must preserve:

1. runtime/network flexibility across deploy, probe, seeding, and rollback
2. dedicated awsvpc execution helpers for network lookup and valid AWS CLI JSON assembly
3. the rule that `FARGATE` requires `awsvpc`

## 9. Operator Defaults and Overrides

The CircleCI design must support:

1. concrete top-level pipeline parameters for defaults:
   - `EC2` or `FARGATE`
   - `awsvpc` or `non-awsvpc`
2. per-job overrides when needed
3. clear precedence:
   - job override
   - pipeline default
   - environment-scoped variable
   - safe fallback

Do not use abstract `auto` behavior.

## 10. Probe-Specific Rules

Preserve these rules exactly:

1. probe is capability-flexible across valid ECS execution modes
2. probe is operationally pinned to `FARGATE + awsvpc` by default
3. normal deployment probe uses fetch-first with build fallback
4. rollback verification probe uses fetch-only
5. probe updates pointers only on successful deployment probe
6. rollback verification probe must not advance pointers

## 11. Rollback Rules

Preserve these rules exactly:

1. automatic rollback target comes from `last-known-good-task-definition-arn`
2. manual rollback resolves in this order:
   - explicit ARN
   - manifest record
   - SSM fallback
3. rollback must follow actual service runtime/network mode
4. rollback must always be followed by verification probe
5. rollback verification failure must fail the workflow

## 12. Seeding Rules

Preserve these rules exactly:

1. seeding is a one-off ECS task
2. seeding has its own task definition and image policy
3. seeding writes success/failure manifests
4. seeding writes manifests before failing the workflow if the task fails

## 13. Promotion Rules

Preserve these rules exactly:

1. promotion source of truth is a successful lower-environment manifest
2. promotion copies the approved image into production-region ECR
3. production deploy reuses the normal deploy flow against the promoted image
4. production approval occurs before promotion/deploy

## 14. CircleCI Output Requirements

Your answer must include:

1. CircleCI workflow structure
2. reusable commands/jobs and what each owns
3. pipeline parameter strategy
4. workspace/artifact handoff design
5. context and variable strategy
6. approval strategy for prod
7. failure handling strategy
8. example `.circleci/config.yml` structural layout
9. mapping from original GitHub architecture to CircleCI architecture

## 15. Tone and Standard

Write as a senior engineer would:

1. precise
2. list-oriented
3. operationally realistic
4. clear about tradeoffs
5. explicit about default behavior versus override behavior
6. opinionated where ambiguity would create production risk

Do not provide a shallow overview.

Do not simply translate syntax.

Design the CircleCI pipeline as a faithful architectural equivalent of the existing ECS CI/CD system.

## 16. Phased Implementation Roadmap

In addition to the architecture itself, your answer must include a phased implementation roadmap for CircleCI so the pipeline can be built incrementally with controlled rollout and feedback loops.

The phased roadmap must preserve the final target architecture while breaking implementation into practical stages.

### Phase 1: Core Delivery Foundation

Implement first:

1. pipeline parameter strategy for environment and action type
2. reusable deploy job
3. reusable probe job
4. deployment metadata handoff through workspaces or artifacts
5. SSM pointer read/write support
6. S3 manifest write support
7. push/manual/API trigger model

Expected outcome:

1. dev deployment works end to end
2. deployment probe determines success
3. successful deploy updates trusted pointers
4. failed deploy writes failure manifest

Validation goals:

1. one successful dev deploy
2. one failed dev probe path with correct manifest writing
3. region and environment scoping confirmed correct

### Phase 2: Recovery Foundation

Implement next:

1. automatic rollback job
2. manual rollback job
3. rollback target resolution order
4. rollback manifest writing
5. rollback verification probe

Expected outcome:

1. deployment failure triggers deterministic rollback
2. manual rollback can be executed safely
3. rollback is verified, not assumed

Validation goals:

1. failed deploy -> automatic rollback -> verification success
2. manual rollback by explicit ARN
3. manual rollback by SSM fallback

### Phase 3: Artifact and Image Policy Maturity

Implement next:

1. caller-owned image policy across deploy, probe, and seeding
2. fetch-first probe behavior
3. fetch-only rollback verification probe
4. promotion manifest structure
5. production image promotion flow

Expected outcome:

1. image strategy is explicit and reviewable
2. probe image reuse reduces redundant builds
3. production deploys can reuse validated lower-environment artifacts

Validation goals:

1. first probe builds image when missing
2. later probe fetches existing image
3. promotion deploy uses promoted image instead of rebuild

### Phase 4: Operational Task Expansion

Implement next:

1. seed-database job pattern
2. optional migration task pattern
3. optional cache warmup pattern
4. optional feature-toggle enable pattern

Expected outcome:

1. one-off operational tasks are first-class and reusable
2. deploy workflow stays clean instead of accumulating ad hoc steps

Validation goals:

1. seed success and failure both write manifests
2. one additional operational task pattern is proven reusable

### Phase 5: Production Guardrails

Implement next:

1. prod approval job
2. release version pipeline parameter
3. change ticket pipeline parameter
4. change freeze validation
5. break-glass override model
6. deployment concurrency lock per environment/component

Expected outcome:

1. prod rollout becomes policy-controlled instead of purely parameter-driven
2. overlapping deploy/rollback races are reduced

Validation goals:

1. prod requires approval and release metadata
2. freeze-window logic blocks unauthorized release
3. concurrency controls prevent overlapping prod deploys

### Phase 6: Telemetry-Aware Release Validation

Implement next:

1. CloudWatch or equivalent metrics validation after probe
2. observation window for higher environments
3. rollback trigger on metrics breach

Expected outcome:

1. pipeline validates not only basic health but also service behavior after cutover
2. rollback can be triggered by operational degradation, not just probe failure

Validation goals:

1. simulated alarm breach causes release failure
2. prod or staging validation uses both probe and telemetry gates

### Phase 7: Promotion Ladder and Staging

Implement next:

1. introduce `staging` as a first-class environment
2. promote `dev -> staging -> prod`
3. optionally require a soak period before prod promotion

Expected outcome:

1. production promotion becomes more realistic and better controlled
2. lower environments and pre-prod validation become easier to reason about

Validation goals:

1. staging deployment and promotion flow works
2. prod promotion consumes validated staging manifest

### Phase 8: Progressive Delivery

Implement last unless urgently required:

1. blue/green deploy strategy
2. or canary/weighted traffic shift strategy
3. lifecycle validation hooks around traffic movement
4. rollback behavior integrated with progressive strategy

Recommended first choice:

1. blue/green with ECS CodeDeploy or equivalent traffic-switch orchestration

Expected outcome:

1. production releases reduce full-traffic blast radius
2. rollback semantics improve for high-risk environments

Validation goals:

1. successful blue/green rollout with validation hooks
2. failed blue/green rollout with automatic recovery behavior

## 17. Phase-by-Phase Output Requirement

Your answer must not only describe the final CircleCI architecture. It must also provide, for each phase:

1. what to build
2. what CircleCI constructs to use
3. what existing phases it depends on
4. how to validate the phase before moving on
5. what risks are reduced by that phase

## 18. Implementation Philosophy

The phased plan must follow these principles:

1. do not require the entire architecture to be implemented before seeing value
2. prioritize deploy correctness and rollback safety before enterprise complexity
3. add governance and telemetry after the core deploy/recovery path is stable
4. add progressive delivery after the simpler release model is already reliable
5. preserve the same end-state architecture while allowing incremental adoption

# Working-Architecture Drift Notes

## Purpose

This document captures the changes that drifted beyond the earlier summaries in:

- [change.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\change.md)
- [design_spec.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\design_spec.md)

The key point is not just that the implementation changed. The important point is that these drifts are the changes that made the pipeline behave correctly in real runs across `dev` and `prod`.

This file therefore focuses on:

- what drifted
- how the running behavior differs from the earlier documented intent
- why the drift happened
- why that drift improved correctness and reliability

---

## 1. Region Handling Became Explicit in ECS Runner Boundaries

### Earlier documented tendency

The earlier documentation emphasized environment-scoped variable resolution inside reusable workflows, but region handling at the ECS action boundary was not called out as a hard contract.

### Running change

The ECS runner actions now explicitly support region-aware execution and the reusable workflows that call them pass `vars.AWS_REGION` into the action layer.

Affected mechanics:

- `.github/actions/ecs-run-task/action.yml`
- `.github/actions/ecs-run-task-awsvpc/action.yml`
- `.github/actions/ecs-rollback-service/action.yml`

Affected callers:

- `reusable-deploy-service.yml`
- `reusable-probe-environment.yml`
- `reusable-seed-database.yml`
- `reusable-auto-rollback.yml`
- `reusable-manual-rollback.yml`

### Why this drift happened

The pipeline started targeting different AWS regions for `dev` and `prod`. Relying only on ambient CLI defaults was too implicit for a multi-region architecture.

### Why this made the pipeline work

Without explicit region propagation:

- ECS operations could accidentally target the wrong region
- cross-environment behavior became harder to debug
- reusable actions became less trustworthy in multi-region execution

This drift made ECS execution deterministic.

---

## 2. Runtime and Network Defaults Moved from Abstract “Auto” Behavior to Concrete Operator Choices

### Earlier documented tendency

The design had a concept of workflow-level default launch/network policy, and earlier iterations allowed an `auto` mode.

### Running change

The top-level deploy and promotion flows now prefer concrete defaults:

- `EC2` or `FARGATE`
- `awsvpc` or `non-awsvpc`

instead of an `auto` mode.

### Why this drift happened

`auto` looked flexible in theory, but in practice it hid too much behavior:

- operators could not easily tell what would actually run
- test runs became harder to reason about
- fallback chains became harder to read and review

### Why this made the pipeline work

Concrete dispatch defaults improved:

- operator clarity
- test repeatability
- reviewability of runtime decisions

This drift reduced ambiguity at the exact point where deployment mistakes are expensive.

---

## 3. Probe Was Intentionally Pinned Back to Fargate + awsvpc for Operational Reasons

### Earlier documented tendency

The newer design expanded probe execution to support:

- `FARGATE + awsvpc`
- `EC2 + awsvpc`
- `EC2 + non-awsvpc`

This was architecturally useful and remains true as a capability.

### Running change

Even though probe now supports all three execution combinations, the top-level workflow intentionally overrides probe-style jobs to use:

- `probe_launch_type: FARGATE`
- `probe_network_mode: awsvpc`

for:

- normal deployment probe
- auto-rollback recovery verification
- manual rollback recovery verification

### Why this drift happened

Real runs showed that EC2 probe tasks were noticeably slower to stop than Fargate probe tasks.

### Why this made the pipeline work

Probe is a short-lived verification workload, not the main application runtime. For that kind of job, faster start/stop and cleaner isolation mattered more than matching every possible runtime choice.

This drift kept:

- architecture flexible
- operational default fast

That is a good example of real execution refining a correct but too-generic abstraction.

---

## 4. Temporary Hardcoded awsvpc Fallbacks Were Added in Reusable Workflows

### Earlier documented tendency

The design correctly preferred:

- explicit inputs
- environment variables

for awsvpc networking decisions.

### Running change

Temporary fallback resolution was added inside some reusable workflows when awsvpc networking inputs are empty.

Examples include:

- seeder execution fallback
- deploy-service awsvpc fallback
- probe fallback defaults

These resolve values such as:

- subnet tag names
- security group names
- `assign_public_ip`

from environment-aligned conventions when callers omit them.

### Why this drift happened

The architecture was correct, but the current project needed to stay runnable while inputs were still being standardized and while environment wiring was still being refined.

### Why this made the pipeline work

Without these fallbacks, reusable workflows would fail too early during real testing, even when the intended infrastructure convention was already known.

This drift improved:

- testability
- incremental rollout of the architecture
- ability to keep moving without fully perfect environment-variable wiring on day one

It is intentionally a pragmatic drift, not a final ideal-state design.

---

## 5. Environment Binding Was Confirmed to Belong Inside Reusable Workflows, Not the Caller

### Earlier documented tendency

Both `change.md` and `design_spec.md` already describe the move toward resolving environment-specific values inside reusable workflows.

### Running change

Real prod/dev failures proved that this was not just a style preference. It became a hard architectural rule.

The concrete failure mode was:

- a prod execution path resolving dev-scoped values such as a dev ECR repository name

### Why this drift happened

GitHub Actions caller-side resolution can happen before the callee job is bound to the correct environment.

### Why this made the pipeline work

This change directly fixed:

- prod/dev variable crossover
- wrong-region/wrong-repo targeting
- fragile assumptions about caller scoping

This is one of the most important drifts because it turned a conceptually reusable architecture into a truly multi-environment-safe one.

---

## 6. Rollback Had to Follow the Real Service Runtime Model

### Earlier documented tendency

Rollback was already reusable, but earlier behavior still leaned toward EC2/non-awsvpc assumptions.

### Running change

Rollback now tracks service runtime shape and can execute correctly for:

- `EC2 + non-awsvpc`
- `EC2 + awsvpc`
- `FARGATE + awsvpc`

This logic now flows through:

- rollback reusable workflows
- `ecs-rollback-service`
- the same ECS runner actions used elsewhere

### Why this drift happened

A rollback that assumes one service model is not a true rollback mechanism in a mixed ECS architecture.

### Why this made the pipeline work

This drift aligned rollback with real deployment modes instead of historical assumptions.

That matters because:

- a rollback path that cannot restore the target service mode is not an actual recovery path
- Fargate environments must not be recovered via EC2-shaped rollback assumptions

---

## 7. Push-Based Change Detection Was Tightened to Match Real Deployment Intent

### Earlier documented tendency

The design specified better path detection semantics and zero-SHA handling.

### Running change

The working implementation now reflects a stricter interpretation:

- push-based deployment should happen only for actual deployable application paths
- workflow-only edits should not auto-run deployment logic
- branch-vs-main drift must not be used for deploy triggers

### Why this drift happened

Real feature-branch behavior showed that comparing against `main` or allowing workflow-file edits to trigger deploys created noisy and misleading executions.

### Why this made the pipeline work

This drift made deploy triggering:

- intentional
- quieter
- easier to reason about

Manual dispatch remained the correct place for workflow experimentation.

---

## 8. Probe Image Strategy Became More Operationally Refined Than the Original Design

### Earlier documented tendency

The earlier docs already captured fetch-first probe behavior and fetch-only rollback verification.

### Running change

The running implementation made the distinction sharper:

- first probe can build if the repository is empty
- later probe runs fetch instead of rebuilding
- rollback verification never rebuilds

### Why this drift happened

Real runs made it clear that rebuilding probe images in later verification stages was redundant and slowed recovery feedback.

### Why this made the pipeline work

This drift improved:

- speed
- determinism
- cost
- reduced noise in ECR and CI logs

This is a smaller drift than environment binding or rollback-mode fixes, but it materially improved the day-to-day behavior of the pipeline.

---

## 9. The Working Architecture Needed More Explicit Documentation Than the Original Docs Provided

### Earlier documented tendency

`change.md` and `design_spec.md` captured the major refactor well, but once the implementation started surviving real execution, several operational truths became sharper than the original wording.

Examples:

- region must be propagated explicitly to action boundaries
- probe should stay capability-flexible but operationally pinned to Fargate by default
- temporary awsvpc defaults are sometimes necessary to keep testing moving
- environment binding is not just cleaner, it is required for correctness

### Why this drift happened

The original documents described the architecture at a clean design level.

The running system exposed where:

- defaults were too abstract
- platform behavior was more opinionated than expected
- operational reliability required stricter contracts

### Why this made the pipeline work

This drift forced the documentation to become more honest about what the implementation really needs, not just what the ideal abstraction suggested.

---

## 10. Summary of the Differences That Most Directly Made the Pipeline Work

The changes below are the ones that most directly turned the architecture from “well-structured” into “working reliably”:

1. environment-scoped value resolution moved inside environment-bound reusable workflows
2. ECS runner actions and rollback paths became region-explicit and multi-region-safe
3. rollback execution was aligned with the actual service runtime model
4. probe remained architecture-flexible but was operationally pinned to Fargate for speed
5. push detection stopped treating branch drift and workflow edits as deploy intent
6. temporary awsvpc defaults kept reusable workflows runnable while configuration matured

If these changes had not drifted from the earlier documentation and earlier behavior, the architecture would still look clean, but it would not have behaved reliably in real multi-environment, multi-region execution.

---

## Final Interpretation

The drift described here should be read as implementation hardening, not architectural regression.

The original refactor established the right major structure:

- top-level orchestration
- reusable workflow job flows
- composite actions for mechanics
- SSM pointers
- S3 manifests

The later drifts made that structure operationally correct by tightening:

- environment scoping
- region scoping
- runtime scoping
- deployment intent detection
- probe and rollback behavior

Those are the differences that made the pipeline not just cleaner, but dependable.

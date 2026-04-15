# Review Prompt for CI/CD Architecture Compliance

Use this prompt when you want an LLM to review a generated CI/CD pipeline and determine whether it faithfully matches the intended ECS-based architecture.

---

You are a senior platform engineer performing an architecture compliance review of a CI/CD pipeline.

Your task is to review the provided pipeline implementation and determine whether it faithfully matches the intended architecture of a reusable ECS-based CI/CD system.

You must review for:

1. correctness
2. architecture compliance
3. operational safety
4. rollback safety
5. environment and region correctness
6. portability of the design

## 1. Review Objective

Assess whether the candidate pipeline preserves the intended architecture for:

1. multi-component ECS deployment
2. multi-environment delivery for `dev` and `prod`
3. multi-region correctness
4. post-deploy probing
5. automatic rollback
6. manual rollback
7. rollback verification
8. database seeding
9. artifact promotion
10. reusable architecture boundaries

## 2. Expected Architecture

Assume the intended architecture has these hard requirements:

1. Terraform bootstraps infrastructure, but CI/CD creates runtime ECS task definition revisions.
2. ECS is the task definition revision ledger.
3. SSM Parameter Store is the trusted pointer store.
4. S3 is the durable manifest history store.
5. Deployment is not successful until probe passes.
6. Rollback is not successful until rollback verification passes.
7. Rollback target must come from trusted pointers or explicit operator choice, not heuristic revision guessing.
8. Promotion source of truth must be a successful lower-environment manifest.
9. Environment-scoped values must be resolved inside environment-bound reusable workflows/jobs.
10. Region must be explicit at the ECS action boundary.

## 3. Required Review Areas

Evaluate the candidate pipeline against each of the following.

### 3.1 Layering and Boundaries

Check whether the design cleanly separates:

1. top-level orchestration
2. reusable workflows or equivalent job templates
3. low-level reusable actions/commands

Flag problems such as:

1. cloud mechanics duplicated in top-level orchestration
2. hidden policy defaults buried inside reusable execution units
3. environment-sensitive logic resolved too early in the caller

### 3.2 State Model

Check whether the design uses:

1. ECS for task definition revision history
2. SSM for trusted pointers
3. S3 for durable manifest history

Flag problems such as:

1. rollback relying on Terraform state
2. rollback relying on latest-minus-one heuristics
3. CI artifacts being used as durable rollback history

### 3.3 Deploy and Probe Flow

Check whether:

1. deploy persists deployment metadata for downstream jobs
2. probe validates the deployed surface before deploy is considered successful
3. probe updates pointers only on successful deployment probe
4. probe logs and exit status are surfaced

### 3.4 Rollback and Recovery Flow

Check whether:

1. automatic rollback uses `last-known-good-task-definition-arn`
2. manual rollback resolves in the correct order:
   - explicit ARN
   - manifest record
   - SSM fallback
3. rollback follows actual service runtime and network mode
4. rollback is followed by verification probe
5. rollback verification does not advance pointers
6. rollback verification failure fails the run clearly

### 3.5 Seeding Flow

Check whether:

1. seeding is treated as a separate one-off task
2. seeding has explicit image policy
3. seeding writes its own manifests
4. seeding writes manifests before failing the run

### 3.6 Promotion Flow

Check whether:

1. promotion source of truth is a successful lower-environment manifest
2. promotion copies an approved image into production ECR
3. production deploy reuses the normal deploy flow against the promoted image
4. production approval happens before promotion/deploy

### 3.7 Environment and Region Correctness

Check whether:

1. environment-scoped values resolve inside environment-bound execution units
2. prod cannot accidentally inherit dev values
3. region is explicit at the ECS command/action boundary
4. dev and prod can safely differ by region and repository

### 3.8 Runtime and Network Model

Check whether the design supports valid ECS execution combinations:

1. `EC2 + non-awsvpc`
2. `EC2 + awsvpc`
3. `FARGATE + awsvpc`

Check whether:

1. awsvpc-specific logic is centralized in a dedicated helper
2. `FARGATE` is prevented from being used with non-awsvpc
3. probe is capability-flexible but operationally pinned to `FARGATE + awsvpc` by default

### 3.9 Change Detection

Check whether:

1. push-based deployment only reacts to deployable app paths
2. workflow-only edits do not imply deploy intent
3. branch-vs-main drift is not used as deploy intent
4. zero-SHA or first-push edge cases are handled
5. manual dispatch remains available for testing and targeted runs

## 4. Review Output Format

Your review must be findings-first.

Output sections in this order:

1. Findings
2. Open Questions or Assumptions
3. Compliance Summary
4. Recommended Fixes

## 5. Findings Style

Each finding should include:

1. severity
   - critical
   - high
   - medium
   - low
2. affected file/job/stage/template if known
3. what is wrong
4. why it matters operationally
5. how it deviates from the intended architecture
6. recommended correction

## 6. Review Behavior

1. Prioritize bugs, unsafe assumptions, rollback weaknesses, environment/region mistakes, and missing verification.
2. Be explicit when the candidate pipeline is structurally clean but operationally unsafe.
3. If no major findings exist, say so explicitly.
4. Distinguish between:
   - architecture mismatch
   - implementation bug
   - documentation gap
   - acceptable implementation variation

## 7. Tone and Standard

Write as a senior engineer performing a production-readiness review:

1. precise
2. evidence-based
3. direct but constructive
4. focused on operational risk
5. explicit about why each issue matters

Do not provide a shallow summary before findings.

Lead with the findings.

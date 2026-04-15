# Compact Prompt for CI/CD Pipeline Architecture

Use this prompt when you want an LLM to recreate the CI/CD architecture in a shorter context window while preserving the important operating rules.

---

You are a senior platform engineer. Design a production-grade CI/CD pipeline architecture for a multi-component ECS application platform.

Write a list-oriented, implementation-ready specification that can be implemented in GitHub Actions, GitLab CI, or CircleCI.

## Requirements

1. The application has these components:
   - `frontend`
   - `backend`
   - `probe`
   - `database-seeder`

2. Infrastructure is bootstrapped by Terraform, but runtime application revisions are created by CI/CD.

3. The design must support:
   - multi-environment delivery, especially `dev` and `prod`
   - multi-region delivery where `dev` and `prod` may differ by AWS region
   - ECS service deploys
   - one-off ECS task execution
   - post-deploy probe
   - automatic rollback
   - manual rollback
   - rollback verification
   - optional database seeding
   - artifact promotion from lower environment to production

## State Model

Use three distinct state stores:

1. ECS
   - task definition revision ledger
   - runtime service/task execution platform

2. SSM Parameter Store
   - trusted deployment pointers
   - at minimum:
     - `current-task-definition-arn`
     - `last-known-good-task-definition-arn`

3. S3
   - durable manifest and audit history
   - store manifests for deployment success/failure, rollback, rollback verification, seeding, and promotion

Do not collapse these responsibilities together.

## Architectural Layers

The design must separate:

1. top-level orchestration
   - triggers
   - change detection
   - matrix routing
   - policy decisions
   - approvals

2. reusable workflows or equivalent job templates
   - environment-bound orchestration
   - deploy/probe/rollback/seeding choreography
   - manifest and pointer transitions
   - runtime/network branching

3. reusable action/command layer
   - ECR build/push/fetch
   - ECS task definition render/register
   - ECS task/service execution
   - ECS wait/log collection
   - SSM pointer helpers
   - S3 manifest helpers
   - awsvpc lookup and network JSON generation

## Required Flows

Specify these flows clearly:

1. detect changes
2. deploy service
3. deployment probe
4. automatic rollback
5. rollback verification probe
6. manual rollback
7. manual rollback verification
8. database seeding
9. promotion

## Critical Operating Rules

1. Deployment is not successful until probe passes.
2. Rollback target must come from trusted pointers or explicit operator choice, not revision guessing.
3. Rollback must always be followed by verification.
4. Rollback verification must not advance pointers.
5. Promotion must use a successful lower-environment manifest as source of truth.
6. Push-based deploy should only trigger for deployable application paths.
7. Workflow-only edits must not imply deploy intent.
8. Push diff must compare against the immediately previous pushed commit, not branch-vs-main.
9. Zero-SHA push events must be handled explicitly.

## Environment and Region Rules

1. Environment-scoped values must be resolved inside reusable workflows bound to the target environment.
2. Do not resolve prod/dev-dependent values too early in the top-level caller.
3. Treat region as explicit at the action boundary.
4. Reusable workflows should pass region intent into low-level ECS execution helpers.

## Runtime and Network Model

Support:

1. `EC2 + non-awsvpc`
2. `EC2 + awsvpc`
3. `FARGATE + awsvpc`

Explain:

1. why deploy, probe, seeding, and rollback should all be capability-flexible
2. why `FARGATE` requires `awsvpc`
3. why awsvpc-specific execution should live in a dedicated helper

## Operator Defaults

Use concrete workflow-level defaults only:

1. `EC2` or `FARGATE`
2. `awsvpc` or `non-awsvpc`

Do not use abstract `auto` behavior.

Explain precedence as:

1. job override
2. workflow default
3. environment variable
4. safe built-in fallback

## Probe-Specific Rules

1. Probe should support all valid ECS execution modes.
2. Probe should be operationally pinned to `FARGATE + awsvpc` by default.
3. Normal deploy probe should use fetch-first with build fallback.
4. Rollback verification probe should use fetch-only.

## Seeding Rules

1. Seeder uses its own task definition.
2. Seeder uses explicit build/fetch policy.
3. Seeder writes its own manifests.
4. Seeder writes manifests before failing the workflow.

## Output Format

Write the result as a senior engineer would.

The output must include:

1. System Goals
2. System Components
3. State Model
4. Layered Architecture
5. Deployment Flow
6. Probe Flow
7. Rollback Flow
8. Seeding Flow
9. Promotion Flow
10. Contracts and Conventions
11. Environment and Region Model
12. Runtime and Network Model
13. Failure Handling
14. Security and IAM
15. Portability Notes
16. Working-Version Refinements

Be precise, detailed, operationally realistic, and explicit about tradeoffs.

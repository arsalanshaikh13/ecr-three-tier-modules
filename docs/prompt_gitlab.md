# GitLab-Focused Prompt for CI/CD Pipeline Architecture

Use this prompt when you want an LLM to generate the GitLab CI version of the ECS-based CI/CD pipeline architecture implemented in this repository.

---

You are a senior platform engineer. Design a GitLab CI/CD pipeline that reproduces the CI/CD architecture of a reusable ECS-based deployment system currently implemented in GitHub Actions.

Your job is not to translate YAML line by line. Your job is to recreate the same architecture, lifecycle, and operational behavior in GitLab CI using GitLab-native concepts.

## 1. Target Outcome

Produce a detailed, list-oriented architecture and implementation specification for a GitLab CI system that supports:

1. multi-component ECS delivery
2. multi-environment delivery for at least `dev` and `prod`
3. multi-region AWS delivery when `dev` and `prod` differ by region
4. deploy, probe, rollback, rollback verification, seeding, and promotion
5. reusable GitLab templates and job contracts
6. environment-scoped configuration and approval boundaries

## 2. Source Architecture You Must Preserve

The GitLab design must preserve these architectural truths:

1. Terraform bootstraps infrastructure, but CI/CD creates runtime ECS task definition revisions.
2. ECS is the revision ledger.
3. SSM Parameter Store is the trusted deployment pointer store.
4. S3 is the durable deployment/rollback/seeding/promotion manifest store.
5. deployment is not considered successful until probe passes.
6. rollback is not considered successful until rollback verification passes.
7. promotion uses a successful lower-environment manifest as its source of truth.

## 3. Required GitLab Mapping

Map the GitHub-style architecture into GitLab-native constructs.

You must explicitly describe how to implement equivalents for:

1. top-level orchestration workflow
2. reusable workflows
3. reusable actions
4. matrix-style environment/component targeting
5. workflow dispatch inputs
6. manual approval gates
7. artifact handoff
8. environment-scoped variables
9. child pipelines or hidden templates where appropriate

Recommended GitLab building blocks to consider:

1. `stages`
2. hidden job templates with `extends`
3. child pipelines when useful
4. `needs`
5. `artifacts`
6. `dependencies`
7. `when: manual`
8. protected environments
9. scoped CI/CD variables
10. pipeline variables

## 4. Required Pipeline Stages

Design GitLab stages or equivalent logical groups for:

1. `detect`
2. `deploy`
3. `probe`
4. `rollback`
5. `verify_rollback`
6. `seed`
7. `promote`

Explain whether each stage should use:

1. hidden reusable templates
2. child pipelines
3. parameterized jobs
4. manual jobs

## 5. Required Jobs / Templates

Design the GitLab equivalent of these reusable execution units:

1. deploy service
2. probe environment
3. automatic rollback
4. manual rollback
5. rollback verification probe
6. seed database
7. promote image

Each template/job spec should define:

1. purpose
2. required inputs/variables
3. outputs or artifacts
4. failure behavior
5. SSM/S3/ECS responsibilities
6. environment-binding behavior

## 6. State and Artifact Rules

Preserve the state model exactly:

1. ECS = task definition revision history
2. SSM = trusted pointers
3. S3 = durable manifests

Use GitLab artifacts only for workflow-local handoff such as deployment metadata between jobs.

Do not treat GitLab artifacts as the durable rollback history source.

## 7. Change Detection Rules

The GitLab design must preserve the same intent rules:

1. push pipelines should only trigger deployment logic when deployable app paths change
2. workflow-only edits should not trigger deploys
3. branch-vs-main drift must not be used as deploy intent
4. zero-SHA-like edge cases or branch-creation cases must be handled explicitly
5. manual pipelines should remain the primary path for workflow testing and targeted runs

## 8. Environment and Region Rules

The GitLab design must preserve these correctness rules:

1. environment-scoped values must resolve inside the environment-bound job/template
2. do not resolve prod/dev-sensitive values too early in parent orchestration
3. region must be explicit at the ECS action/command boundary
4. dev and prod may use different regions and ECR repositories

## 9. Runtime and Network Rules

The GitLab design must support:

1. `EC2 + non-awsvpc`
2. `EC2 + awsvpc`
3. `FARGATE + awsvpc`

You must preserve:

1. runtime/network flexibility across deploy, probe, seeding, and rollback
2. dedicated awsvpc execution helpers for awsvpc network lookup and valid AWS CLI JSON construction
3. the rule that `FARGATE` requires `awsvpc`

## 10. Operator Defaults and Overrides

The GitLab design must support:

1. concrete top-level pipeline variables for defaults:
   - `EC2` or `FARGATE`
   - `awsvpc` or `non-awsvpc`
2. per-job overrides when needed
3. clear precedence:
   - job override
   - pipeline default
   - environment-scoped variable
   - safe fallback

Do not use abstract `auto` behavior.

## 11. Probe-Specific Rules

Preserve these rules exactly:

1. probe is capability-flexible across valid ECS execution modes
2. probe is operationally pinned to `FARGATE + awsvpc` by default
3. normal deployment probe uses fetch-first with build fallback
4. rollback verification probe uses fetch-only
5. probe updates pointers only on successful deployment probe
6. rollback verification probe must not advance pointers

## 12. Rollback Rules

Preserve these rules exactly:

1. automatic rollback target comes from `last-known-good-task-definition-arn`
2. manual rollback resolves in this order:
   - explicit ARN
   - manifest record
   - SSM fallback
3. rollback must follow actual service runtime/network mode
4. rollback must always be followed by verification probe
5. rollback verification failure must fail the pipeline

## 13. Seeding Rules

Preserve these rules exactly:

1. seeding is a one-off ECS task
2. seeding has its own task definition and image policy
3. seeding writes success/failure manifests
4. seeding writes manifests before failing the pipeline if the task fails

## 14. Promotion Rules

Preserve these rules exactly:

1. promotion source of truth is a successful lower-environment manifest
2. promotion copies the approved image into production-region ECR
3. production deploy reuses the normal deploy flow against the promoted image
4. production approval occurs before promotion/deploy

## 15. GitLab Output Requirements

Your answer must include:

1. GitLab pipeline stages
2. hidden templates and what each owns
3. child pipeline usage decisions if any
4. job contracts and variable contracts
5. artifact handoff design
6. environment-scoped variable strategy
7. approval strategy for prod
8. failure handling strategy
9. example `.gitlab-ci.yml` structural layout
10. mapping from original GitHub architecture to GitLab architecture

## 16. Tone and Standard

Write as a senior engineer would:

1. precise
2. list-oriented
3. operationally realistic
4. clear about tradeoffs
5. explicit about default behavior versus override behavior
6. opinionated where ambiguity would create production risk

Do not provide a shallow overview.

Do not simply translate syntax.

Design the GitLab pipeline as a faithful architectural equivalent of the existing ECS CI/CD system.

## 17. Phased Implementation Roadmap

In addition to the architecture itself, your answer must include a phased implementation roadmap for GitLab CI so the pipeline can be built incrementally with clear validation points.

The phased roadmap must preserve the final target architecture while breaking implementation into practical stages.

### Phase 1: Core Delivery Foundation

Implement first:

1. environment-scoped variable strategy
2. reusable deploy-service template
3. reusable probe template
4. deployment metadata handoff through GitLab artifacts
5. SSM pointer read/write support
6. S3 manifest write support
7. push/manual trigger model

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

1. automatic rollback template
2. manual rollback template
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

1. seed-database reusable template
2. optional migration task pattern
3. optional cache warmup pattern
4. optional feature-toggle enable pattern

Expected outcome:

1. one-off operational tasks are first-class and reusable
2. deploy workflow stays clean instead of accumulating ad hoc shell steps

Validation goals:

1. seed success and failure both write manifests
2. one additional operational task pattern is proven reusable

### Phase 5: Production Guardrails

Implement next:

1. prod approval gate
2. release version input
3. change ticket input
4. change freeze validation
5. break-glass override model
6. deployment concurrency lock per environment/component

Expected outcome:

1. prod rollout becomes policy-controlled instead of purely trigger-driven
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

Implement last unless the team already requires it urgently:

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

## 18. Phase-by-Phase Output Requirement

Your answer must not only describe the final GitLab architecture. It must also provide, for each phase:

1. what to build
2. what GitLab constructs to use
3. what existing phases it depends on
4. how to validate the phase before moving on
5. what risks are reduced by that phase

## 19. Implementation Philosophy

The phased plan must follow these principles:

1. do not require the entire architecture to be implemented before seeing value
2. prioritize deploy correctness and rollback safety before enterprise complexity
3. add governance and telemetry after the core deploy/recovery path is stable
4. add progressive delivery after the simpler release model is already reliable
5. preserve the same end-state architecture while allowing incremental adoption

## 20. Cost and Implementation Demarcation

In addition to the phased roadmap, your answer must append a cost-aware implementation demarcation for each phase.

The purpose of this demarcation is to help the implementer distinguish between:

1. GitLab CI template/YAML/repository work that is primarily control-plane logic
2. Terraform and AWS architecture work that can create, modify, or expand billable AWS resources

The answer must preserve the main phased roadmap but add a practical planning layer for cost and implementation tracking.

### 20.1 Demarcation categories

For each phase, classify the work into one or more of these categories:

1. `gitlab_ci_only`
   - `.gitlab-ci.yml`
   - hidden templates
   - child pipeline definitions
   - shell scripts
   - job parameter wiring
   - artifact and dependency wiring
   - notification/reporting logic

2. `terraform_aws`
   - Terraform root module changes
   - Terraform module changes
   - new AWS resources
   - modified AWS architecture
   - CloudWatch alarms
   - CodeDeploy resources
   - new staging infrastructure
   - load balancer or network topology changes

3. `mixed`
   - requires both GitLab CI changes and Terraform/AWS changes

4. `cost_increasing`
   - likely adds ongoing or event-driven AWS cost

5. `cost_neutral`
   - mostly control-plane logic with little or no direct AWS resource increase

6. `cost_reducing`
   - retention, cleanup, lifecycle, or optimization work that lowers spend over time

### 20.2 Required demarcation details per phase

For each implementation phase, your answer must state:

1. whether the phase is primarily `gitlab_ci_only`, `terraform_aws`, or `mixed`
2. which GitLab files are likely to be affected
3. which Terraform files, modules, or AWS architecture areas are likely to be affected
4. whether the phase is likely `cost_increasing`, `cost_neutral`, or `cost_reducing`
5. recommended sequencing if the team wants to minimize AWS cost during rollout

### 20.3 GitLab file examples to reference when relevant

When identifying GitLab-side implementation work, reference likely files such as:

1. `.gitlab-ci.yml`
2. included GitLab CI template files
3. child pipeline files
4. deployment scripts
5. manifest/pointer helper scripts
6. notification scripts

### 20.4 Terraform/AWS file examples to reference when relevant

When identifying infrastructure-side implementation work, reference likely areas such as:

1. Terraform root module wiring
2. ECS service modules
3. load balancer modules
4. CodeDeploy-related modules
5. monitoring/alarm resources
6. ECR lifecycle policies
7. S3 lifecycle rules
8. staging environment tfvars and module instantiation

### 20.5 Cost-aware implementation recommendation

Your answer must include an explicit recommendation for a cost-aware implementation order.

The recommendation should generally favor:

1. GitLab CI and control-plane phases first
2. Terraform/AWS-expanding phases later
3. staging and progressive delivery only after core deploy/recovery safety is mature

### 20.6 Planning intent

The demarcation must help an engineer answer these practical questions:

1. which phases can be implemented with mostly GitLab CI file changes
2. which phases are likely to create new AWS resources and therefore cost money
3. which files should be tracked in implementation tickets
4. how to schedule high-cost phases later for better budget control

### 20.7 Important constraint

Do not rewrite or replace the phased roadmap.

Append the demarcation after the phased plan so the prompt remains both:

1. an architecture-generation prompt
2. a cost-aware implementation-planning prompt

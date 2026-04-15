# Improvements Review and Implementation Plan

## Purpose

This document compares:

1. [advanced.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\tf-modules\ecr-three-tier-tf-modules\advanced.md)
2. [prompt.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\prompt.md)

The goal is to determine how close the current CI/CD architecture is to a real-world production pipeline and to define a practical, executable roadmap for closing the remaining gaps.

This is written from the perspective of a senior engineer reviewing an already-working pipeline that has solid deployment mechanics but has not yet implemented every control, progressive delivery, and release-governance pattern commonly used in larger production environments.

## Executive Assessment

### Overall maturity

The current pipeline is meaningfully closer to a real-world production pipeline than a typical basic GitHub Actions ECS deploy workflow.

It already demonstrates several patterns that many teams only add later:

1. explicit separation of orchestration, reusable workflows, and reusable actions
2. ECS-driven runtime revision management instead of Terraform-driven runtime deployments
3. SSM as a trusted pointer store
4. S3 as an auditable manifest history store
5. post-deploy verification before considering a release successful
6. automatic rollback
7. manual rollback with explicit target resolution order
8. rollback verification as a first-class recovery stage
9. promotion based on validated artifacts rather than blind rebuilds
10. environment-scoped configuration and multi-region awareness

### Real-world production closeness

A practical assessment is:

1. current pipeline is strong in deployment correctness and recovery design
2. current pipeline is moderate in release governance and operational controls
3. current pipeline is lighter than large-company pipelines in progressive delivery, supply-chain assurance, policy enforcement, and metrics-driven rollout control

If measured qualitatively:

1. architecture and rollback maturity: high
2. operational hardening maturity: medium
3. enterprise release governance maturity: medium-low

A fair summary is:

- this pipeline already looks more production-shaped than a simple CI/CD tutorial pipeline
- it is not yet fully comparable to a mature platform pipeline used by large organizations with stricter release controls

## Where the Current Pipeline Is Already Strong

### 1. State modeling is production-worthy

The separation between:

1. ECS for revision history
2. SSM for trusted pointers
3. S3 for durable manifests

is a strong production pattern.

Why this matters:

1. rollback becomes deterministic
2. history is auditable
3. CI artifacts are not abused as long-term deployment state

This is better than many pipelines that only store state implicitly in ECS or try to recover from ad hoc naming conventions.

### 2. Rollback design is stronger than average

The current architecture already supports:

1. automatic rollback after failed probe
2. manual rollback
3. rollback target resolution by explicit ARN, manifest, or SSM fallback
4. rollback verification probe

That rollback verification step is especially important. Many teams stop at �update the ECS service back to the previous revision,� which is incomplete.

### 3. Reusable workflow and action boundaries are healthy

The split between:

1. top-level orchestration
2. reusable job-level workflows
3. composite action mechanics

is closer to a platform engineering design than a repository-local CI script.

This is a strong foundation for multi-repo reuse and future portability.

### 4. Environment correctness has been treated seriously

The move to resolve environment-specific values inside environment-bound reusable workflows is exactly the kind of detail that prevents real prod/dev mistakes.

That is a production-grade correction, not just a style preference.

### 5. Promotion philosophy is good

Promoting tested artifacts instead of rebuilding for prod is a real-world production pattern.

That reduces:

1. nondeterminism
2. environment-specific rebuild drift
3. difficulty proving what actually went to production

## Where the Pipeline Is Still Behind a Mature Production Standard

## 1. Missing pre-deployment governance controls

`advanced.md` asks for:

1. environment validation
2. manual approval for prod
3. change freeze validation
4. version tagging

Your current architecture covers some approval behavior, but it does not yet fully describe or enforce:

1. change freeze windows
2. release-window policies
3. deployment policy validation before execution
4. standardized immutable release versioning beyond image/manifests

Production impact:

1. operations teams often need release blackout periods
2. regulated or higher-risk environments need stronger change authorization
3. production rollouts often require explicit release identity, not just commit SHA

## 2. Progressive delivery is not yet implemented

`advanced.md` expects:

1. rolling deployment
2. blue/green deployment
3. canary deployment
4. weighted traffic shift

Your current pipeline is closer to:

1. standard ECS service deployment
2. probe-based validation after full deploy
3. rollback after failure

That is solid, but it is not yet progressive delivery.

Production impact:

1. full-cutover deployment can expose 100 percent of traffic immediately
2. rollback remains reactive instead of traffic-shift-aware
3. high-sensitivity production systems often prefer canary or blue/green

## 3. Metrics-driven release gates are not yet first-class

Your current probe validates application health at task or endpoint level.

What is still missing from a more production-grade pattern:

1. CloudWatch alarms as rollout gates
2. latency/error-rate regression checks
3. post-release SLO validation windows
4. rollback driven by metrics breach, not just probe failure

Production impact:

1. smoke tests can pass while user-facing error rate rises
2. application can be �healthy� but degraded
3. many mature pipelines combine probe checks with telemetry checks

## 4. Artifact security and supply-chain controls are under-specified

`advanced.md` explicitly includes:

1. security scan
2. SBOM generation
3. artifact metadata creation

Your current prompt covers image preparation conceptually but not strongly enough in terms of:

1. vulnerability gates
2. signature/attestation patterns
3. digest-first promotion policy
4. SBOM retention and auditability

Production impact:

1. large organizations increasingly require image scanning and provenance
2. promoting by tag alone is weaker than promoting by digest
3. security review is usually part of the release path, not an optional extra

## 5. Post-deploy operational jobs are narrower than enterprise practice

You already support database seeding.

What `advanced.md` adds that is not yet fully represented:

1. database migrations as a first-class controlled stage
2. cache warmup
3. feature-flag enablement after validation
4. post-cutover operational hooks

Production impact:

1. seeding is only one kind of one-off operational action
2. many production releases require ordered post-release jobs
3. feature rollout is often decoupled from binary rollout

## 6. Cleanup and retention automation are incomplete

`advanced.md` includes cleanup expectations such as:

1. remove old task definitions
2. remove old container images
3. cleanup temporary resources

Your current architecture is already thoughtful about manifests and state, but it does not yet describe a robust retention strategy for:

1. ECS task definition revisions
2. old ECR images
3. temporary probe artifacts
4. retention windows for manifests and logs

Production impact:

1. repositories and ECS history will grow indefinitely
2. audit data and rollback safety need controlled retention, not endless accumulation
3. cleanup must be policy-aware, not destructive

## 7. Notification and release communication are underdeveloped

`advanced.md` expects:

1. Slack
2. email
3. GitHub deployment status

Your architecture already captures strong manifest and status data, but a mature production pipeline also needs:

1. operator-facing release summaries
2. incident-grade notification on rollback or rollback-verification failure
3. promotion and prod approval notifications

Production impact:

1. silent CI failure is not enough in production
2. rollback events are high-signal operational moments

## 8. Staging environment is not a first-class part of the current architecture

`advanced.md` assumes `dev`, `staging`, and `prod`.

Your current prompt emphasizes `dev` and `prod`.

Production impact:

1. many real-world systems use staging as the environment where pre-prod release certification happens
2. promotion logic usually becomes cleaner with a stronger `dev -> staging -> prod` path

## 9. Release versioning strategy could be stronger

Your pipeline is already good at tracking:

1. commit SHA
2. image URI
3. task definition ARN

A more production-grade release model would also standardize:

1. release version identifier
2. deployment candidate ID
3. promoted artifact digest
4. approved release record

Production impact:

1. operations and business stakeholders often reason in release versions, not raw commit SHAs
2. release audit becomes easier when build identity and release identity are both explicit

## 10. Policy-as-code is not yet an explicit layer

This is not strongly represented in either file, but a more advanced production pattern would include:

1. deployment policy validation as code
2. environment restrictions expressed declaratively
3. release safety checks expressed in one reusable place

Examples:

1. forbid prod deploy outside approved hours unless break-glass
2. require signed image or successful scan before promotion
3. require rollback pointer existence before allowing prod rollout

## Production Gap Summary

The current pipeline is strongest in:

1. deploy mechanics
2. rollback correctness
3. reusable architecture
4. environment-safe execution

The biggest remaining production gaps are:

1. governance and release policy controls
2. progressive delivery
3. telemetry-based validation
4. supply-chain security gates
5. broader post-deploy operational automation
6. cleanup/retention policies
7. operator notification patterns

## Recommended Production-Ready but Still Executable Improvement Pattern

The best next-step pattern for this pipeline is not to jump immediately to full enterprise complexity.

The most executable production-oriented evolution is:

### Phase A: Guarded immutable delivery

Add:

1. release versioning
2. vulnerability scan gate
3. digest-based promotion
4. prod approval metadata
5. Slack/GitHub release notifications

This gives immediate production value without forcing a major deployment-strategy rewrite.

### Phase B: Telemetry-aware rollback

Add:

1. post-deploy CloudWatch alarm evaluation
2. rollback trigger on metrics breach
3. deployment health window after probe

This makes the pipeline more production-realistic while preserving the existing probe-and-rollback structure.

### Phase C: Progressive delivery

Add one progressive delivery strategy first, not all three.

Recommended first choice:

1. blue/green via ECS CodeDeploy for frontend and backend services

Reason:

1. easier to reason about than custom canary weighting at first
2. stronger production story
3. easier rollback semantics than ad hoc weighted shift logic

### Phase D: Release governance and retention

Add:

1. change freeze windows
2. release policy checks
3. retention jobs for ECS/ECR/manifests
4. staging as a promotion checkpoint

## End-to-End Improvement Plan

## Phase 1: Strengthen Artifact Identity and Security

### Goal

Make artifacts promotion-safe, auditable, and security-gated.

### Changes to implement

1. add image vulnerability scanning stage before deploy or promotion
2. generate and persist SBOM for built images
3. record image digest in deployment metadata and manifests
4. promote by digest, not by mutable tag
5. add release version field to manifests and metadata

### Implementation procedure

1. extend image build action to output:
   - `image_uri`
   - `image_digest`
   - `image_tag`
   - `release_version`
2. add a reusable security-scan action or workflow stage using Trivy or equivalent
3. fail deploy or promotion if severity threshold is exceeded
4. persist scan summary as artifact and manifest attachment metadata
5. update promotion workflow so it copies the digest-identified image into prod ECR
6. update manifest schema to include:
   - `releaseVersion`
   - `imageDigest`
   - `scanStatus`
   - `scanSummaryPath`

### Why this helps

1. makes release identity stronger
2. reduces mutable-tag ambiguity
3. brings the pipeline closer to enterprise supply-chain expectations

## Phase 2: Add Pre-Deployment Guardrails

### Goal

Introduce release governance before prod deploys.

### Changes to implement

1. add deployment policy validation stage before deploy jobs
2. add change freeze validation for prod
3. require explicit release reason or ticket reference for prod dispatch
4. standardize prod approval metadata capture

### Implementation procedure

1. create a reusable `reusable-predeploy-guardrails.yml`
2. inputs should include:
   - `environment`
   - `release_version`
   - `change_ticket`
   - `requested_by`
   - `break_glass`
3. implement checks for:
   - valid environment input
   - freeze-window rule
   - required change ticket for prod
   - required release version for prod
4. add workflow-dispatch inputs in `deploy.yml` and `promotion.yml` for:
   - `release_version`
   - `change_ticket`
   - `break_glass_reason`
5. record approved release metadata into manifest and job summary

### Why this helps

1. closer to real change-management practice
2. gives stronger operational traceability
3. makes prod deploy intent explicit

## Phase 3: Add Telemetry-Based Validation

### Goal

Move from smoke-test-only validation to operational validation.

### Changes to implement

1. evaluate CloudWatch alarms after deploy and after rollback verification
2. add a post-deploy observation window
3. rollback automatically on metrics breach

### Implementation procedure

1. define environment-specific CloudWatch alarms for:
   - ALB 5xx rate
   - target response latency
   - ECS service CPU or memory saturation
   - custom application error metrics if available
2. create `reusable-evaluate-release-health.yml`
3. inputs should include:
   - `environment`
   - `component`
   - `observation_window_minutes`
   - `alarm_names`
4. workflow logic:
   - wait configured observation window
   - query alarm state
   - fail if any required alarm is `ALARM`
5. insert this stage after successful probe and before final success marking in higher environments
6. if telemetry validation fails:
   - trigger automatic rollback
   - write telemetry-failure reason into manifest

### Why this helps

1. catches degradations smoke tests miss
2. aligns with real-world release verification
3. preserves your existing rollback model while improving signal quality

## Phase 4: Introduce Progressive Delivery

### Goal

Reduce full-traffic blast radius during production rollout.

### Recommended first implementation

1. blue/green deployment using ECS CodeDeploy

### Why blue/green first

1. simpler rollback semantics than custom weighted canary logic
2. closer to enterprise ECS production patterns
3. easier to document and operate than building custom traffic shifting yourself

### Implementation procedure

1. add Terraform support for ECS CodeDeploy deployment groups
2. create blue and green target group model for frontend and backend services
3. update deploy reusable workflow to branch by deployment strategy:
   - standard rolling
   - blue/green
4. add deploy strategy input:
   - `rolling`
   - `blue_green`
5. use CodeDeploy deployment lifecycle hooks for:
   - pre-traffic validation
   - post-traffic validation
6. map existing probe logic into pre/post-traffic validation where possible
7. keep current rollback model as fallback for non-CodeDeploy strategies

### Why this helps

1. moves pipeline much closer to larger-company release practice
2. reduces production risk during rollout
3. gives cleaner traffic-switch semantics than full cutover deploys

## Phase 5: Expand Post-Deploy Operational Jobs

### Goal

Generalize one-off operational jobs beyond seeding.

### Changes to implement

1. separate migration workflow from seeding workflow
2. add optional cache warmup job
3. add feature-toggle enablement stage after successful validation

### Implementation procedure

1. create `reusable-run-operational-task.yml`
2. support task purposes such as:
   - `migration`
   - `seed`
   - `cache_warmup`
   - `feature_enable`
3. parameterize task definition preparation and execution
4. persist manifests for each operational task category
5. define task ordering:
   - migration before service cutover when backward compatibility requires it
   - seeding after deploy if needed
   - cache warmup after healthy cutover
   - feature enable after telemetry success

### Why this helps

1. production pipelines often coordinate multiple post-release actions
2. keeps deployment logic from becoming overloaded with app-specific shell steps

## Phase 6: Add Cleanup and Retention Policies

### Goal

Control historical growth without weakening rollback safety.

### Changes to implement

1. ECR image retention policy
2. ECS task definition pruning policy
3. S3 manifest lifecycle policy
4. optional probe artifact retention policy

### Implementation procedure

1. define retention policy by environment
   - prod keeps more history than dev
2. implement scheduled cleanup workflow
3. for ECS task definitions:
   - keep all revisions referenced by current manifests and trusted pointers
   - prune only unreferenced stale revisions beyond threshold
4. for ECR images:
   - keep digests referenced by recent successful manifests and current trusted pointers
   - expire unreferenced stale images
5. for S3 manifests:
   - use lifecycle rules by manifest class and age
6. for CloudWatch logs:
   - set log retention explicitly per environment

### Why this helps

1. avoids uncontrolled resource growth
2. preserves rollback safety while reducing clutter

## Phase 7: Add Notification and Release Reporting

### Goal

Make deployment state visible to operators, not just CI logs.

### Changes to implement

1. Slack notifications for deploy, rollback, and prod approval events
2. GitHub deployment status updates
3. high-signal alert on rollback verification failure

### Implementation procedure

1. create reusable notify action/workflow
2. send notifications for:
   - deploy started
   - deploy succeeded
   - deploy failed
   - rollback triggered
   - rollback verification failed
   - production approval requested
   - promotion completed
3. include in notifications:
   - environment
   - component
   - release version
   - image digest
   - task definition ARN
   - workflow URL
4. mark prod releases in GitHub deployment status API if desired

### Why this helps

1. real production pipelines need operational visibility
2. rollback events should not be buried inside job logs

## Phase 8: Introduce Staging as a First-Class Promotion Step

### Goal

Strengthen pre-production certification.

### Changes to implement

1. add `staging` environment to environment matrix and environment-scoped config
2. require promotion path:
   - `dev -> staging -> prod`
3. use staging manifests as prod promotion source where appropriate

### Implementation procedure

1. add GitHub environment and AWS config for staging
2. provision staging ECR, ECS, SSM, and manifest paths
3. update deploy and promotion workflows to include staging as a supported target
4. require staging success and optionally staging soak before prod approval

### Why this helps

1. closer to large-company release flow
2. gives a cleaner promotion ladder
3. improves confidence before prod rollout

## Additional Production-Level but Executable Patterns Not Strongly Covered Yet

## 1. Break-glass deployment path

Add an explicitly audited break-glass mode for prod.

Pattern:

1. prod deploy blocked by normal guardrails
2. operator can override with:
   - break-glass reason
   - stronger approval
   - special manifest annotation

Why useful:

1. supports emergency hotfixes
2. keeps exceptions explicit and auditable

## 2. Deployment concurrency lock per environment

Pattern:

1. only one deploy or rollback may operate on the same environment/component at a time
2. promotion to prod also acquires the prod lock

Why useful:

1. prevents overlapping deployments from corrupting state transitions
2. reduces pointer and manifest races

## 3. Soak-period-based promotion

Pattern:

1. successful staging release must remain healthy for a configured soak period before prod promotion

Why useful:

1. adds time-based confidence without enormous complexity
2. widely used in real production release workflows

## 4. Drift detection for environment configuration

Pattern:

1. periodically validate that environment-scoped CI variables, AWS resources, and expected parameter names still align

Why useful:

1. many deploy failures come from config drift, not code defects
2. catches missing subnet/security-group parameters before release time

## 5. Release bundles and signed release records

Pattern:

1. create a release bundle containing:
   - manifest
   - digest
   - scan result
   - SBOM
   - approval metadata
2. optionally sign the bundle or release record

Why useful:

1. stronger auditability
2. better long-term production traceability

## Suggested Implementation Order

The most practical order for your current pipeline is:

1. Phase 1: artifact identity and security
2. Phase 2: pre-deployment guardrails
3. Phase 3: telemetry-based validation
4. Phase 7: notifications
5. Phase 6: cleanup and retention
6. Phase 5: generalized post-deploy operational tasks
7. Phase 8: staging environment
8. Phase 4: progressive delivery with blue/green

Reason:

1. first strengthen release identity and safety
2. then improve runtime signal quality
3. then improve operator awareness
4. then expand deployment strategy complexity only after the basics are mature

## Final Recommendation

The current pipeline is already a serious, thoughtfully engineered deployment system.

Its strongest real-world qualities are:

1. explicit runtime state design
2. robust rollback philosophy
3. reusable architecture boundaries
4. environment-safe execution behavior

The next production leap should not be �rewrite everything for enterprise complexity.�

The right next move is to preserve the current architecture and add:

1. stronger release governance
2. supply-chain controls
3. telemetry-based release gates
4. staged progressive delivery
5. operator-facing release communication

That path keeps the system executable, understandable, and incrementally closer to the kind of release platform used in larger production environments.

## Cost and Implementation Demarcation by Phase

This section keeps the phased plan intact and adds a practical implementation demarcation so the work can be scheduled with better awareness of:

1. which phases are mostly GitHub Actions YAML and action/workflow logic
2. which phases require Terraform and AWS resource creation or modification
3. which phases are likely to create or increase AWS cost

The goal is to help separate:

1. lower-cost pipeline/control-plane work
2. cloud-resource work that can create ongoing or event-driven AWS charges

## Demarcation Legend

### A. GitHub Actions / Repository Logic

This means changes are primarily in:

1. `.github/workflows/*.yml`
2. `.github/actions/*/action.yml`
3. scripts under `scripts/`
4. manifest/pointer/logging helpers
5. repository documentation and contracts

These changes are usually low direct AWS-cost changes by themselves, although they may trigger existing resources more often.

### B. Terraform / AWS Architecture

This means changes are primarily in:

1. Terraform root module wiring
2. Terraform child modules under `tf-modules/`
3. creation or modification of AWS resources
4. CloudWatch alarms, CodeDeploy groups, staging infrastructure, retention resources, lifecycle rules, or network/load balancer topology

These changes can create direct AWS cost, operational complexity, or both.

## Phase-by-Phase Demarcation

### Phase 1: Strengthen Artifact Identity and Security

Primary implementation type:

1. mostly GitHub Actions / repository logic
2. partial AWS integration depending on chosen scan/SBOM storage model

Mostly affected files:

1. `.github/workflows/deploy.yml`
2. `.github/workflows/promotion.yml`
3. reusable workflows that pass image metadata
4. `.github/actions/ecs-build-push-image/action.yml`
5. `.github/actions/ecr-fetch-image/action.yml`
6. manifest-writing actions
7. `design_spec.md`, `change.md`, `change_new.md` if documentation is updated

Potential Terraform/AWS impact:

1. optional S3 pathing changes for scan or SBOM artifacts
2. optional ECR lifecycle or repository policy adjustments

AWS cost impact:

1. low to medium
2. mostly from additional ECR storage, S3 artifact retention, and security scan execution patterns

Recommendation:

1. do this phase early because it is largely pipeline-controlled and gives strong production value with relatively low AWS cost risk

### Phase 2: Add Pre-Deployment Guardrails

Primary implementation type:

1. overwhelmingly GitHub Actions / repository logic

Mostly affected files:

1. `.github/workflows/deploy.yml`
2. `.github/workflows/promotion.yml`
3. new reusable workflow such as `reusable-predeploy-guardrails.yml`
4. notification or approval helper actions if introduced
5. documentation files

Potential Terraform/AWS impact:

1. usually none
2. optional if freeze-window data or policy data is externalized into AWS-backed config stores

AWS cost impact:

1. negligible to none in the normal case

Recommendation:

1. this is one of the best early phases because it is mostly free from an AWS resource-creation perspective
2. use it to improve release discipline before paying for heavier architecture changes

### Phase 3: Add Telemetry-Based Validation

Primary implementation type:

1. mixed GitHub Actions and Terraform/AWS architecture

Mostly affected repository files:

1. reusable workflows for probe and post-deploy validation
2. new reusable workflow such as `reusable-evaluate-release-health.yml`
3. action helpers for CloudWatch/alarm evaluation
4. deploy and promotion orchestration flows

Terraform/AWS affected files:

1. Terraform root module wiring
2. monitoring-related Terraform modules or alarm definitions
3. ALB, ECS, and application metric/alarm resources

Likely affected Terraform areas:

1. CloudWatch alarms for ALB 5xx
2. CloudWatch alarms for latency
3. ECS service CPU/memory alarms
4. optional custom metric alarms

AWS cost impact:

1. medium
2. alarms, custom metrics, log ingestion, and telemetry retention can add real ongoing cost

Recommendation:

1. implement the YAML/workflow layer only after deciding the minimum useful alarm set
2. start with a small alarm footprint in `prod` first, then expand
3. avoid creating large numbers of custom metrics early unless needed

### Phase 4: Introduce Progressive Delivery

Primary implementation type:

1. heavily Terraform/AWS architecture based
2. plus GitHub Actions orchestration changes

Mostly affected repository files:

1. deploy reusable workflows
2. promotion/deploy orchestration
3. rollback integration logic
4. probe integration hooks

Terraform/AWS affected files:

1. load balancer modules
2. ECS service modules
3. CodeDeploy modules or new modules
4. target group definitions
5. listener rules or weighted routing resources

Likely affected Terraform areas:

1. frontend/backend ALB target groups
2. CodeDeploy deployment groups
3. additional listener or routing definitions
4. blue/green service topology support

AWS cost impact:

1. medium to high
2. extra target groups, longer overlap of old/new tasks, and blue/green traffic duplication can increase cost materially

Recommendation:

1. do not start here first
2. only begin after rollback, probe, and telemetry foundations are already stable
3. if cost-sensitive, prefer implementing blue/green in `prod` only first

### Phase 5: Expand Post-Deploy Operational Jobs

Primary implementation type:

1. mostly GitHub Actions / repository logic
2. some AWS runtime cost impact from more one-off tasks

Mostly affected files:

1. new reusable operational-task workflows
2. deploy orchestration and task sequencing
3. ECS task-definition preparation actions
4. wait/log collection actions

Potential Terraform/AWS impact:

1. low unless new IAM roles, log groups, or task definitions require Terraform changes
2. possible Secrets Manager or SSM additions if new tasks require new runtime config

AWS cost impact:

1. low to medium
2. each migration, warmup, or feature-toggle task consumes ECS runtime and CloudWatch logs

Recommendation:

1. build the reusable workflow pattern first
2. add only one additional operational task type at a time so task-cost and runtime behavior remain easy to observe

### Phase 6: Add Cleanup and Retention Policies

Primary implementation type:

1. mixed GitHub Actions and Terraform/AWS architecture

Mostly affected repository files:

1. scheduled cleanup workflows
2. cleanup scripts
3. manifest and pointer safety checks

Terraform/AWS affected files:

1. ECR lifecycle policies
2. S3 lifecycle rules
3. CloudWatch log retention configuration
4. optional retention-related IAM permissions

AWS cost impact:

1. this phase is cost-reducing over time
2. but incorrect implementation can damage rollback safety

Recommendation:

1. implement after manifest/pointer policies are mature
2. preserve anything referenced by current trusted pointers and recent manifests
3. treat this as a cost-optimization phase with strong safety checks, not just housekeeping

### Phase 7: Add Notification and Release Reporting

Primary implementation type:

1. mostly GitHub Actions / repository logic

Mostly affected files:

1. deploy, rollback, probe, and promotion workflows
2. reusable notification actions or scripts
3. job summary/reporting helpers

Potential Terraform/AWS impact:

1. usually none if using Slack/webhook/GitHub deployment status
2. possible SNS/EventBridge integration if you choose AWS-native notification paths later

AWS cost impact:

1. negligible in the common implementation path

Recommendation:

1. this is another strong early-to-mid phase because it is cheap and increases operator effectiveness quickly

### Phase 8: Introduce Staging as a First-Class Promotion Step

Primary implementation type:

1. heavily Terraform/AWS architecture based
2. plus workflow/orchestration expansion

Mostly affected repository files:

1. deploy and promotion orchestration
2. environment matrix logic
3. manifest pathing and promotion logic
4. scripts that operate per environment

Terraform/AWS affected files:

1. root Terraform module and tfvars
2. ECR repos for staging
3. ECS cluster/services/task execution config for staging
4. SSM parameter namespaces for staging
5. S3 manifest path usage and possibly supporting policies
6. Route53, ALB, network, and app infrastructure if staging mirrors prod closely

AWS cost impact:

1. high relative to YAML-only phases
2. staging often means near-duplicate environment cost depending on how complete the environment is

Recommendation:

1. treat this as a deliberate infrastructure expansion project
2. estimate monthly cost before building full staging
3. if needed, start with partial staging that mirrors deployment flow but uses scaled-down capacity

## Recommended Cost-Aware Execution Order

If cost control is important, the most efficient order is:

1. Phase 2: pre-deployment guardrails
2. Phase 7: notification and release reporting
3. Phase 1: artifact identity and security
4. Phase 5: post-deploy operational task expansion
5. Phase 3: telemetry-based validation
6. Phase 6: cleanup and retention
7. Phase 8: staging environment
8. Phase 4: progressive delivery

Why this order helps:

1. the first four phases are mostly repository/YAML/control-plane work
2. they improve release quality without forcing large AWS architecture changes
3. the later phases introduce the more expensive infrastructure patterns

## File Tracking Recommendations

To make cost-aware planning easier, track each improvement item under one of these labels:

1. `gha_only`
   - workflow YAML, composite actions, scripts, docs
2. `terraform_aws`
   - Terraform modules, tfvars, AWS architecture changes
3. `mixed`
   - requires both workflow and infrastructure changes
4. `cost_increasing`
   - likely adds ongoing AWS cost
5. `cost_neutral`
   - mostly control-plane or logic changes
6. `cost_reducing`
   - retention, cleanup, or optimization changes

Recommended practical approach:

1. create implementation tickets per phase
2. annotate each ticket with the labels above
3. estimate AWS blast radius before merging `terraform_aws` or `mixed` items
4. merge `gha_only` items more aggressively because they are easier to test and cheaper to iterate on

## Final Cost-Aware Recommendation

If the goal is to move toward a more production-grade pipeline while controlling AWS spend, then:

1. prioritize GitHub Actions and policy-based phases first
2. defer staging and progressive delivery until the core release model is mature
3. treat telemetry and staging as budgeted architecture steps
4. treat cleanup/retention as both a safety and cost-control investment

This keeps the current pipeline improving in a financially controlled way while preserving the long-term production architecture direction.

## Phase 3 Repository-Specific Implementation Plan

This section translates Phase 3 into the actual files and resource boundaries in the current repository so implementation work can be done deliberately instead of generically.

The current state is:

1. the workflow layer already has probe-based validation
2. rollback is already a first-class workflow path
3. there is no reusable telemetry-evaluation workflow yet
4. the current CloudWatch Terraform module at `tf-modules/ecr-three-tier-tf-modules/modules/cw_logs` only creates log groups, not alarms
5. the workflow layer does not currently query CloudWatch alarm state before marking deployment recovery as successful

That means Phase 3 is a true `mixed` implementation:

1. GitHub Actions changes are required to evaluate release health
2. Terraform changes are required to create the alarm objects that the workflow will evaluate

### What I Would Change In The Workflow Layer

The workflow goal is not to replace probe validation. The right design is:

1. keep probe as the fast correctness check
2. add telemetry evaluation as the operational observation check
3. trigger rollback when telemetry says the new revision is unhealthy even if the smoke probe passed

### New Reusable Workflow

Create:

1. `.github/workflows/reusable-evaluate-release-health.yml`

Responsibility:

1. wait for a configurable observation window after deploy success
2. read CloudWatch alarm state for the environment and component
3. emit a machine-readable health decision
4. fail the workflow if any required alarm is in `ALARM`

Suggested inputs:

1. `environment`
2. `component`
3. `project_name`
4. `observation_window_minutes`
5. `alarm_names`
6. `health_purpose`

Suggested outputs:

1. `telemetry_status`
2. `telemetry_reason`
3. `evaluated_alarm_names`

Suggested job logic:

1. bind the job to the selected GitHub environment
2. configure AWS credentials using the environment-scoped region/account vars
3. sleep for the observation window
4. call `aws cloudwatch describe-alarms`
5. collect all alarms that are currently `ALARM`
6. return `healthy` when none are in `ALARM`
7. return `failed` when one or more are in `ALARM`
8. write the result into job summary and manifest-friendly output

### New Composite Action

Create:

1. `.github/actions/cloudwatch-evaluate-alarms/action.yml`

Responsibility:

1. accept a region and comma-separated alarm names
2. query alarm state via AWS CLI
3. output:
   - `alarm_state_summary`
   - `alarming_names`
   - `evaluation_status`

Why keep this as a separate action:

1. the reusable workflow stays orchestration-focused
2. the AWS alarm query logic remains swappable and testable
3. later GitLab CI or CircleCI implementations can reuse the same conceptual contract

### Changes In `deploy.yml`

Modify:

1. `.github/workflows/deploy.yml`

Add a new stage after `probe-app` and after `verify-rollback-recovery` style validation paths:

1. `evaluate-release-health`

Recommended placement for normal deploy flow:

1. `build-and-deploy`
2. `probe-app`
3. `evaluate-release-health`
4. if telemetry fails, run `rollback`
5. if rollback succeeds, run `verify-rollback-recovery`

Recommended placement for manual rollback flow:

1. `manual-rollback`
2. `verify-manual-rollback-recovery`
3. `evaluate-rollback-health`

Suggested new `deploy.yml` inputs:

1. `enable_telemetry_gate`
2. `observation_window_minutes`

Suggested `with:` values passed from `deploy.yml`:

1. `environment: ${{ matrix.environment }}`
2. `component: ${{ matrix.component }}`
3. `project_name: ${{ vars.PROJECT_NAME }}`
4. `observation_window_minutes: ${{ github.event_name == 'workflow_dispatch' && inputs.observation_window_minutes || 5 }}`
5. `alarm_names: ...`

The important design decision here is:

1. `deploy.yml` should remain the place where pipeline graph decisions live
2. the reusable telemetry workflow should not decide by itself whether rollback happens
3. rollback should still be orchestrated by the top-level workflow so run history stays readable

### Alarm Name Resolution In Workflow

Do not hardcode raw CloudWatch alarm names inside the reusable workflow.

Instead:

1. define environment-scoped GitHub variables for alarm names, or
2. pass alarm names from `deploy.yml` based on `matrix.component`

Recommended environment variables:

1. `FRONTEND_RELEASE_ALARM_NAMES`
2. `BACKEND_RELEASE_ALARM_NAMES`

Example:

1. frontend deploys evaluate frontend ALB and frontend ECS service alarms
2. backend deploys evaluate backend ALB and backend ECS service alarms

This matches the design direction you already adopted for subnet and security-group separation.

### Manifest And Summary Changes

Update release manifests to include telemetry decision data.

Likely affected areas:

1. `.github/actions/deployment-manifest-write/action.yml`
2. `.github/actions/deployment-manifest-write-batch/action.yml`
3. telemetry evaluation reusable workflow summary output

Add fields such as:

1. `telemetryStatus`
2. `telemetryReason`
3. `evaluatedAlarmNames`
4. `observationWindowMinutes`

This matters because Phase 3 is not complete if telemetry only exists in transient workflow logs.

### What I Would Change In Terraform

The current module:

1. `tf-modules/ecr-three-tier-tf-modules/modules/cw_logs/main.tf`

currently creates:

1. application log groups
2. ECS exec log group

It does not create:

1. CloudWatch alarms
2. metric filters
3. dashboard resources
4. SNS alarm actions

So the Terraform side of Phase 3 should extend monitoring beyond logs.

### Recommended Terraform Change Strategy

The cleanest implementation is:

1. keep `cw_logs` focused on log groups
2. add alarm resources either:
   - to the same `cw_logs` module if you want a monitoring-centric module, or
   - to a new `cw_alarms` module if you want sharper separation

My recommendation for this repository is:

1. create a new module such as `modules/cw_alarms`

Reason:

1. log groups and telemetry gates are related but not identical concerns
2. a dedicated alarms module will be easier to reason about, version, and reuse
3. it avoids overloading `cw_logs` with responsibilities that are no longer just logs

### Terraform Resources To Add

The minimum useful alarm set for Phase 3 is:

1. frontend ALB 5xx alarm
2. frontend target response time alarm
3. backend ALB 5xx alarm
4. backend target response time alarm
5. frontend ECS CPU high alarm
6. frontend ECS memory high alarm
7. backend ECS CPU high alarm
8. backend ECS memory high alarm

Potential Terraform resources:

1. `aws_cloudwatch_metric_alarm` for ALB 5xx
2. `aws_cloudwatch_metric_alarm` for target response time
3. `aws_cloudwatch_metric_alarm` for ECS CPU utilization
4. `aws_cloudwatch_metric_alarm` for ECS memory utilization

If you later want application-level error signals, add:

1. `aws_cloudwatch_log_metric_filter`
2. `aws_cloudwatch_metric_alarm` tied to that custom metric

That should be a second step, not the first step.

### Terraform Inputs Required

Whether you extend `cw_logs` or create `cw_alarms`, the monitoring module will need these values wired in:

1. frontend ALB full name or suffix
2. backend ALB full name or suffix
3. frontend target group full name or suffix
4. backend target group full name or suffix
5. ECS cluster name
6. frontend ECS service name
7. backend ECS service name
8. environment suffix
9. common tags

This means Terraform root wiring will likely need outputs from:

1. `module.lb`
2. `module.ecs_fargate` or `module.ecs_ec2`

### Terraform Files Likely To Change

If implementing with a new module:

1. `tf-modules/ecr-three-tier-tf-modules/modules/cw_alarms/main.tf`
2. `tf-modules/ecr-three-tier-tf-modules/modules/cw_alarms/variables.tf`
3. `tf-modules/ecr-three-tier-tf-modules/modules/cw_alarms/outputs.tf`
4. `ecr-three-tier-modules/root/main.tf`

If implementing inside the existing log module:

1. `tf-modules/ecr-three-tier-tf-modules/modules/cw_logs/main.tf`
2. `tf-modules/ecr-three-tier-tf-modules/modules/cw_logs/variables.tf`
3. `tf-modules/ecr-three-tier-tf-modules/modules/cw_logs/outputs.tf`
4. `ecr-three-tier-modules/root/main.tf`

### Additional Outputs Needed From Existing Modules

The alarm module cannot reliably target ALB and ECS metrics unless Terraform exposes the right dimensions.

That means you will likely need outputs added to:

1. `tf-modules/ecr-three-tier-tf-modules/modules/lb/outputs.tf`
2. `tf-modules/ecr-three-tier-tf-modules/modules/ecs_fargate/outputs.tf`
3. `tf-modules/ecr-three-tier-tf-modules/modules/ecs_ec2/outputs.tf`

Examples of useful outputs:

1. `frontend_alb_arn_suffix`
2. `backend_alb_arn_suffix`
3. `frontend_tg_arn_suffix`
4. `backend_tg_arn_suffix`
5. `frontend_service_name`
6. `backend_service_name`
7. `cluster_name`

These are the exact kinds of outputs Phase 3 needs because CloudWatch alarm dimensions are identifier-driven.

### Concrete Minimal Phase 3 Rollout

A cost-aware and executable first iteration should be:

1. add frontend/backend ALB 5xx alarms
2. add frontend/backend ECS CPU high alarms
3. create `reusable-evaluate-release-health.yml`
4. create `cloudwatch-evaluate-alarms` composite action
5. wire `deploy.yml` so telemetry evaluation runs only for `prod` at first
6. keep rollback logic exactly as it is, but trigger it from telemetry failure as well as probe failure

Why this is the right first cut:

1. it gives meaningful operational signal quickly
2. it avoids custom metric complexity
3. it limits new CloudWatch cost
4. it preserves your current deploy/probe/rollback architecture

### What I Would Not Change Yet

I would not do these in the first Phase 3 cut:

1. log-metric-filter-based application alarms
2. SNS or EventBridge fanout for alarm actions
3. dashboards
4. large numbers of low-value alarms
5. telemetry gating in `dev`

Reason:

1. the objective of Phase 3 is release validation, not full observability platform buildout
2. too many alarms too early will create noise and cost before the deployment contract is proven

### Final Recommended Implementation Sequence For This Repository

1. add required outputs from `lb` and ECS modules
2. create a dedicated `cw_alarms` Terraform module instead of overloading `cw_logs`
3. wire the alarms module into `root/main.tf`
4. expose alarm names through environment-scoped GitHub variables
5. create `.github/actions/cloudwatch-evaluate-alarms/action.yml`
6. create `.github/workflows/reusable-evaluate-release-health.yml`
7. insert telemetry evaluation into `deploy.yml` after successful probe
8. extend rollback trigger conditions to include telemetry failure
9. add telemetry result fields into manifests and job summaries

This gives a Phase 3 implementation that is:

1. modular
2. production-aligned
3. cost-aware
4. compatible with the current reusable workflow and manifest-driven architecture
## Phase 6 Repository-Specific Implementation Plan

This section translates Phase 6 into the actual files and operational boundaries in the current repository so cleanup and retention work can be implemented without weakening rollback safety.

The current state is:

1. the ECR module already has a lifecycle policy, but it is hardcoded to keep the last 30 images
2. the S3 deployment manifest bucket exists, but it does not yet have lifecycle rules for older manifest classes
3. the CloudWatch log module already sets retention, but the values are hardcoded in the shared module
4. ECS task definition history is not currently pruned anywhere
5. rollback safety now depends on both SSM pointers and S3 deployment manifest history, including `manifest-index.json`

That means Phase 6 is a true `mixed` implementation:

1. Terraform changes are required for ECR, S3, and CloudWatch retention
2. GitHub Actions changes are required for ECS task definition pruning because Terraform should not manage mutable ECS revision history

### What I Would Change In The Terraform Layer

The Terraform goal is to control historical growth for AWS-managed storage surfaces while preserving the rollback working set.

### ECR Retention

Files affected:

1. `tf-modules/ecr-three-tier-tf-modules/modules/ecr/main.tf`
2. `tf-modules/ecr-three-tier-tf-modules/modules/ecr/variables.tf`
3. `root/main.tf`
4. `root/variables.tf`
5. `root/tfvars/dev.tfvars`
6. `root/tfvars/prod.tfvars`

Implementation:

1. replace the hardcoded lifecycle count with a variable such as `ecr_image_retention_count`
2. wire that variable from root into the shared module
3. set explicit values in `dev.tfvars` and `prod.tfvars`

Design decision:

1. use count-based retention first, not age-only retention
2. count-based retention matches rollback needs better because rollback depends on recent image history more than raw calendar age
3. prod should keep more image history than dev

### S3 Manifest Retention

Files affected:

1. `tf-modules/ecr-three-tier-tf-modules/modules/s3/main.tf`
2. `tf-modules/ecr-three-tier-tf-modules/modules/s3/variables.tf`
3. `root/main.tf`
4. `root/variables.tf`
5. `root/tfvars/dev.tfvars`
6. `root/tfvars/prod.tfvars`

Implementation:

1. add S3 lifecycle configuration for deployment manifest objects
2. keep successful manifests longer than failure or probe noise
3. expire older noncurrent object versions to control versioning growth
4. keep `manifest-index.json` and recent successful manifests as the operator-facing working set

Design decision:

1. the manifest index is now the fast history surface for operators and rollback helpers
2. lifecycle policy should reduce bulk history growth without deleting the index or the most recent successful lineage
3. rollback and investigation speed matter more than aggressively minimizing object count

### CloudWatch Log Retention

Files affected:

1. `tf-modules/ecr-three-tier-tf-modules/modules/cw_logs/main.tf`
2. `tf-modules/ecr-three-tier-tf-modules/modules/cw_logs/variables.tf`
3. `root/main.tf`
4. `root/variables.tf`
5. `root/tfvars/dev.tfvars`
6. `root/tfvars/prod.tfvars`

Implementation:

1. replace hardcoded `retention_in_days` values with variables such as:
2. `app_log_retention_days`
3. `ecs_exec_log_retention_days`
4. wire those values from root into the shared module
5. set explicit values in `dev.tfvars` and `prod.tfvars`

Design decision:

1. app logs and ECS exec logs serve different operational purposes
2. app logs usually deserve longer retention than exec logs
3. prod should usually keep more history than dev

### What I Would Change In The Workflow Layer

The workflow goal is to prune ECS task definition history safely, because ECS revisions are mutable operational state and should not be deleted by Terraform.

### New Cleanup Workflow

Create:

1. `.github/workflows/reusable-cleanup-retention.yml`
2. `.github/workflows/cleanup-retention.yml`
3. `.github/actions/ecs-prune-task-definitions/action.yml`

Responsibility:

1. run on a schedule or manual dispatch
2. read trusted SSM deployment pointers
3. read S3 `manifest-index.json` history for each component/environment
4. keep all task definition revisions referenced by:
5. current SSM pointer
6. last-known-good SSM pointer
7. recent successful manifest lineage
8. deregister only stale unreferenced task definition revisions beyond threshold

Design decision:

1. task definition pruning is a control-plane cleanup concern, not an infrastructure reconciliation concern
2. the cleanup job should start in dry-run mode first
3. dry-run allows the retention model to be reviewed before any ECS revision is actually removed

### Suggested Root Variables For Phase 6

Add variables in `root/variables.tf` and set them in `dev.tfvars` and `prod.tfvars`:

1. `ecr_image_retention_count`
2. `successful_manifest_retention_days`
3. `failed_manifest_retention_days`
4. `rollback_manifest_retention_days`
5. `app_log_retention_days`
6. `ecs_exec_log_retention_days`
7. `ecs_task_definition_retention_count`
8. `cleanup_dry_run_enabled`

Design decision:

1. retention values for AWS-managed resources belong in Terraform inputs
2. cleanup execution behavior such as dry-run mode can also be mirrored into workflow inputs or environment variables for faster operational iteration

### What I Would Not Do In Phase 6

1. I would not let Terraform try to prune ECS task definition revisions
2. I would not delete image digests or manifest objects solely by age if they are still part of the recent rollback working set
3. I would not lifecycle away `manifest-index.json`

### Recommended Implementation Order

1. implement Terraform retention controls for ECR, S3, and CloudWatch logs
2. wire explicit values through root and tfvars so dev and prod can diverge safely
3. create the cleanup workflow and ECS pruning action
4. start the cleanup workflow in dry-run mode
5. review dry-run output against manifest history and rollback expectations
6. enable real pruning only after the keep-set logic proves correct

### Why This Helps

1. reduces uncontrolled historical growth across ECR, S3, and CloudWatch
2. preserves rollback safety by keeping trusted pointers and manifest history as the retention source of truth
3. makes cleanup intentional and auditable instead of ad hoc shell deletion
4. turns Phase 6 into a cost-reducing step without weakening deployment recovery

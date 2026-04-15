# Prompt Index

This directory contains reusable prompt files for generating, porting, and reviewing the ECS-based CI/CD pipeline architecture designed in this repository.

## Prompt Files

### 1. `prompt.md`

Use for:

1. full architecture generation
2. detailed CI/CD design specification generation
3. recreating the entire pipeline architecture in a platform-agnostic way

Best when:

1. you want the most complete prompt
2. you want a senior-engineer-level architecture spec
3. context size is not a major constraint

### 2. `prompt_compact.md`

Use for:

1. shorter-context architecture generation
2. faster iterations with smaller LLM context windows
3. preserving the key architecture rules in a more compact format

Best when:

1. you want a smaller prompt
2. you still need the important operating rules
3. you are working with tighter model context limits

### 3. `prompt_gitlab.md`

Use for:

1. generating the GitLab CI equivalent of this pipeline
2. mapping GitHub reusable workflow architecture into GitLab templates, stages, and jobs
3. producing a GitLab-native design rather than a literal YAML translation

Best when:

1. the target platform is GitLab CI
2. you want guidance on `stages`, hidden templates, `extends`, artifacts, manual jobs, and approvals

### 4. `prompt_circleci.md`

Use for:

1. generating the CircleCI equivalent of this pipeline
2. mapping the architecture into CircleCI jobs, commands, workflows, workspaces, and approvals
3. producing a CircleCI-native design rather than a literal syntax conversion

Best when:

1. the target platform is CircleCI
2. you want guidance on pipeline parameters, reusable commands, workspaces, contexts, and approval jobs

### 5. `prompt_review.md`

Use for:

1. reviewing whether another generated pipeline matches the intended architecture
2. performing architecture-compliance review
3. production-readiness review of deploy/probe/rollback/promotion behavior

Best when:

1. you already have a candidate pipeline
2. you want findings-first review output
3. you want to identify drift, unsafe assumptions, or missing rollback safeguards

## Suggested Usage Flow

### Architecture creation flow

1. start with `prompt.md`
2. use `prompt_compact.md` when a smaller prompt is needed
3. use `prompt_gitlab.md` or `prompt_circleci.md` when targeting a specific CI platform

### Architecture review flow

1. generate the candidate architecture using one of the generation prompts
2. review the result using `prompt_review.md`
3. compare the output against:
   - `design_spec.md`
   - `.github/WORKFLOW_ARCHITECTURE.md`
   - `change_new.md`

## Supporting Documents

These prompts are based on the architecture documented in:

1. [design_spec.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\design_spec.md)
2. [.github/WORKFLOW_ARCHITECTURE.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\.github\WORKFLOW_ARCHITECTURE.md)
3. [change.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\change.md)
4. [change_new.md](C:\Users\DELL\ArsVSCode\CS50p_project\project_aFinal\website\website2_0\animations\scroll\aws_three_tier_arch\three-tier-terragrunt\ecr\terraform-ecr\terraform_modules\ecr-three-tier-modules\change_new.md)

## Practical Recommendation

If you are unsure which prompt to use:

1. use `prompt.md` for creation
2. use `prompt_gitlab.md` or `prompt_circleci.md` for platform-specific generation
3. use `prompt_review.md` to validate the result afterward

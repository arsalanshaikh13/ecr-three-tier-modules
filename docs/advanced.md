Act as a Senior Staff DevOps Engineer designing a production-grade AWS ECS Continuous Delivery pipeline.

Design a realistic enterprise-grade end-to-end deployment pipeline using:

- AWS ECS (Fargate or EC2 launch type)
- GitHub Actions
- Terraform (module-based infrastructure)
- OIDC authentication from GitHub Actions to AWS
- Multi-environment (dev, staging, prod)
- Multi-region capable architecture

The pipeline must reflect real-world production deployment patterns used in large companies.

Design an end-to-end CD pipeline including the following stages:

1. Pre-Deployment Guardrails

- Environment validation
- Manual approval (prod)
- Change freeze window validation
- Version tagging

2. Artifact Preparation

- Docker build
- Security scan (Trivy or equivalent)
- SBOM generation (optional)
- Push to ECR
- Artifact metadata creation

3. Deployment Preparation

- Generate ECS task definition
- Register new task revision
- Store deployment manifest
- Track commit SHA, image tag, timestamp

4. Deployment Strategy
   Support:

- Rolling deployment
- Blue/Green deployment
- Canary deployment

Prefer:

- Blue/Green using ALB weighted routing
- or ECS CodeDeploy

5. Deployment Execution

- Update ECS service
- Deploy new task definition
- Wait for tasks to become healthy

6. Probe / Health Check
   Include:

- ALB health check
- HTTP smoke tests
- Readiness probe
- Timeout handling

7. Traffic Shift
   Implement:

- Canary traffic shift (10% → 25% → 50% → 100%)
  OR
- Blue/Green swap

8. Post Deploy Validation
   Check:

- CloudWatch metrics
- Error rate
- Latency
- CPU/memory spikes

If validation fails:

- Trigger automatic rollback

9. Rollback Strategy
   Implement:

- Automatic rollback
- Manual rollback workflow
- Rollback to previous task definition revision

10. Post Deployment Jobs
    Include:

- Database migration
- Seed database
- Cache warmup
- Feature toggle enable

11. Deployment Manifest / Audit
    Create:

- deployment.json
  Include:
- commit SHA
- image tag
- task definition revision
- environment
- success/failure
- rollback reference

12. Cleanup

- Remove old task definitions (keep last 5)
- Remove old container images
- Cleanup temporary resources

13. Notification
    Send:

- Slack
- Email
- GitHub Deployment status

Design output should include:

1. High-level architecture diagram (text or ASCII)
2. GitHub Actions workflow structure
3. Recommended folder structure
4. Terraform module structure
5. Deployment sequence diagram
6. Example GitHub Actions YAML workflow
7. Rollback workflow YAML
8. Multi-environment promotion strategy (dev → staging → prod)
9. Observability integration (CloudWatch / Datadog optional)
10. Security best practices

Use modern best practices:

- GitHub OIDC
- Immutable deployments
- Infrastructure as Code
- Versioned deployments
- Zero downtime deployments

Make the pipeline realistic, production-ready, and used by mid-to-large scale companies.

Do not simplify. Design this as a real enterprise production pipeline.

Return:

- Architecture explanation
- YAML examples
- Step-by-step flow
- Production considerations

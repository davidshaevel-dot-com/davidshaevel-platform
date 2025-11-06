# Deployment Runbook

Step-by-step procedures for deploying the DavidShaevel.com platform.

## Quick Reference

**Automated Deployment:** Push to main triggers automatic deployment
**Manual Trigger:** `gh workflow run backend-deploy.yml --field environment=dev`
**Rollback:** `git revert <commit>` then push, or manual ECS service update
**Monitoring:** `gh run watch <id>` or `aws ecs describe-services`

---

## Normal Deployment (Automated)

### Backend Changes

1. Make changes in `backend/` directory
2. Commit: `git commit -m "feat(backend): description"`
3. Push: `git push origin main`
4. Monitor: `gh run list --workflow=backend-deploy.yml --limit 1`
5. Verify: `curl https://davidshaevel.com/api/health`

**Timeline:** ~5-7 minutes total

### Frontend Changes

1. Make changes in `frontend/` directory  
2. Commit: `git commit -m "feat(frontend): description"`
3. Push: `git push origin main`
4. Monitor: `gh run list --workflow=frontend-deploy.yml --limit 1`
5. Verify: `curl https://davidshaevel.com/`

**Timeline:** ~5-7 minutes total

---

## Manual Deployment

### Trigger via GitHub Actions

```bash
# Backend to dev
gh workflow run backend-deploy.yml --field environment=dev

# Frontend to dev
gh workflow run frontend-deploy.yml --field environment=dev
```

### Complete Manual Deployment (if CI/CD unavailable)

```bash
# 1. Build and tag image
cd backend/  # or frontend/
IMAGE_TAG=$(git rev-parse --short HEAD)
docker build -t backend:$IMAGE_TAG .

# 2. Login to ECR
aws ecr get-login-password --region us-east-1 --profile davidshaevel-dev | \
  docker login --username AWS --password-stdin 108581769167.dkr.ecr.us-east-1.amazonaws.com

# 3. Push to ECR
docker tag backend:$IMAGE_TAG 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:$IMAGE_TAG
docker push 108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend:$IMAGE_TAG

# 4. Update ECS service (or use Terraform)
# See detailed manual deployment procedure below
```

---

## Rollback Procedures

### Automated Rollback (Recommended)

```bash
# 1. Revert problematic commit
git revert <bad-commit-sha>

# 2. Push to trigger redeploy
git push origin main

# 3. Monitor deployment
gh run watch <run-id>
```

### Manual Immediate Rollback

```bash
# 1. List task definitions
aws ecs list-task-definitions --profile davidshaevel-dev \
  --family-prefix dev-davidshaevel-backend --sort DESC --max-items 10

# 2. Update service to previous revision
aws ecs update-service --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --service dev-davidshaevel-backend \
  --task-definition dev-davidshaevel-backend:42

# 3. Wait for stabilization
aws ecs wait services-stable --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend

# 4. Verify
curl https://davidshaevel.com/api/health
```

---

## Troubleshooting

### Deployment Stuck

```bash
# View workflow logs
gh run view <run-id> --log-failed

# Check ECS service
aws ecs describe-services --profile davidshaevel-dev \
  --cluster dev-davidshaevel-cluster \
  --services dev-davidshaevel-backend
```

### Common Issues

**ECR Authentication Failure:**
- Verify GitHub secrets: `gh secret list --env dev`
- Check ECR repos exist: `aws ecr describe-repositories`

**ECS Tasks Not Starting:**
- Check CloudWatch logs: `aws logs tail /ecs/dev-davidshaevel/backend --since 10m`
- Verify health check endpoint
- Check database connectivity

**Frontend Not Updating:**
- Invalidate CloudFront cache:
  ```bash
  aws cloudfront create-invalidation --profile davidshaevel-dev \
    --distribution-id EJVDEMX0X00IG --paths "/*"
  ```

### Monitoring Commands

```bash
# List recent workflow runs
gh run list --workflow=backend-deploy.yml --limit 5

# Watch workflow in real-time
gh run watch <run-id>

# Tail application logs
aws logs tail /ecs/dev-davidshaevel/backend --since 30m --follow
aws logs tail /ecs/dev-davidshaevel/frontend --since 30m --follow

# Check ECS task status
aws ecs list-tasks --profile davidshaevel-dev --cluster dev-davidshaevel-cluster
aws ecs describe-tasks --profile davidshaevel-dev --cluster dev-davidshaevel-cluster --tasks <task-arn>

# Check ALB target health
aws elbv2 describe-target-health --profile davidshaevel-dev --target-group-arn <arn>
```

---

## Emergency Procedures

### Complete Service Outage

1. Verify outage: `curl -I https://davidshaevel.com/`
2. Check ECS services: `aws ecs describe-services ...`
3. Check recent deployments: `gh run list --limit 5`
4. Rollback immediately (manual procedure above)
5. Create incident postmortem

### Database Migration Failure

1. Stop deployments: Cancel running workflows
2. Connect to database and assess state
3. Manual recovery if needed
4. Fix migration script
5. Test locally with integration tests
6. Redeploy via CI/CD

---

## Deployment Checklist

### Pre-Deployment
- [ ] Code reviewed and tested locally
- [ ] Tests passing (`npm run test`, `npm run lint`)
- [ ] Database migrations tested (if any)
- [ ] Backup task definition revision noted

### During Deployment
- [ ] Monitor workflow run
- [ ] Watch ECS deployment progress
- [ ] Check CloudWatch logs for errors

### Post-Deployment
- [ ] All endpoints return 200 OK
- [ ] Application functionality verified
- [ ] No errors in CloudWatch logs
- [ ] Update Linear issues

---

## Key Endpoints

- **Frontend:** https://davidshaevel.com/
- **Frontend Health:** https://davidshaevel.com/health
- **Backend API:** https://davidshaevel.com/api/health
- **Projects API:** https://davidshaevel.com/api/projects

## Key Resources

- **ECS Cluster:** dev-davidshaevel-cluster
- **Backend Service:** dev-davidshaevel-backend
- **Frontend Service:** dev-davidshaevel-frontend
- **CloudFront Distribution:** EJVDEMX0X00IG
- **Backend Log Group:** /ecs/dev-davidshaevel/backend
- **Frontend Log Group:** /ecs/dev-davidshaevel/frontend

---

**Last Updated:** November 6, 2025

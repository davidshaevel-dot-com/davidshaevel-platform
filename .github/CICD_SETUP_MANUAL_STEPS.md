# CI/CD Setup - Manual Steps

This document contains the manual steps required to complete CI/CD setup after Terraform has created the IAM infrastructure.

**Context:** We use a hybrid approach - Terraform manages IAM users/policies, but credentials are generated and stored manually to keep them out of Terraform state.

---

## Part 1: Generate AWS Access Keys (5 min)

### Prerequisites

- ✅ Terraform applied successfully (IAM user and policy created)
- ✅ AWS Console access to account `108581769167`
- ✅ IAM permissions to create access keys

### Steps

1. **Navigate to IAM User**
   - Open AWS Console: https://console.aws.amazon.com/iam/
   - Navigate to **Users** → Search for `dev-davidshaevel-github-actions`
   - Click on the user name

2. **Create Access Key**
   - Click **Security credentials** tab
   - Scroll to **Access keys** section
   - Click **Create access key**
   - Select use case: **Application running outside AWS**
   - (Optional) Add description: "GitHub Actions CI/CD for ECS deployments"
   - Click **Create access key**

3. **Save Credentials Securely**

   ⚠️ **CRITICAL:** You will only see the secret once!

   - Copy **Access key ID** (starts with `AKIA...`)
   - Click "Show" and copy **Secret access key**
   - Click **Download .csv file** as backup
   - Store in password manager (1Password, LastPass, etc.)

4. **Verify**
   - Confirm key status shows **Active**
   - Note the creation date

**Example format:**
```
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

---

## Part 2: Configure GitHub Environment and Secrets (7 min)

**Why Environments?** We use GitHub Environments to match our Terraform structure (`terraform/environments/dev/`). This makes it easy to add `prod` later with the same secret names but different values, and enables deployment protection rules.

### Prerequisites

- ✅ Access keys from Part 1
- ✅ GitHub repository admin access
- ✅ Terraform outputs available

### Steps

#### Step 2.1: Create `dev` Environment (2 min)

1. **Navigate to Environments**
   - Go to: https://github.com/davidshaevel/davidshaevel-platform
   - Click **Settings** → **Environments**
   - Click **New environment**

2. **Create Development Environment**
   - Name: `dev` (exactly, lowercase)
   - Click **Configure environment**

3. **Configure Environment (Optional Settings)**
   - **Environment URL**: `https://davidshaevel.com` (for deployment tracking)
   - **Protection rules**: Leave empty for now (we'll add for prod later)
   - **Deployment branches**: No restriction (default)
   - Settings auto-save

#### Step 2.2: Add Secrets to `dev` Environment (5 min)

1. **Navigate to Environment Secrets**
   - Still in Settings → Environments → `dev`
   - Scroll down to **Environment secrets** section
   - Click **Add secret**

2. **Add 9 Environment Secrets**

   **Important:** Add these to the **`dev` environment**, not repository secrets!

   Add each secret one at a time using the values below:

   | Secret Name | Value | Source |
   |-------------|-------|--------|
   | `AWS_ACCESS_KEY_ID` | `AKIA...` | From Part 1 |
   | `AWS_SECRET_ACCESS_KEY` | `wJalr...` | From Part 1 |
   | `AWS_REGION` | `us-east-1` | Fixed value |
   | `AWS_ACCOUNT_ID` | `108581769167` | Fixed value |
   | `ECR_BACKEND_REPOSITORY` | See below | Terraform output |
   | `ECR_FRONTEND_REPOSITORY` | See below | Terraform output |
   | `ECS_CLUSTER` | See below | Terraform output |
   | `ECS_BACKEND_SERVICE` | See below | Terraform output |
   | `ECS_FRONTEND_SERVICE` | See below | Terraform output |

3. **Get Terraform Output Values**

   Run from `terraform/environments/dev/`:
   ```bash
   AWS_PROFILE=davidshaevel-dev terraform output
   ```

   Copy these exact values:
   ```
   ECR_BACKEND_REPOSITORY=108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/backend
   ECR_FRONTEND_REPOSITORY=108581769167.dkr.ecr.us-east-1.amazonaws.com/davidshaevel/frontend
   ECS_CLUSTER=dev-davidshaevel-cluster
   ECS_BACKEND_SERVICE=dev-davidshaevel-backend
   ECS_FRONTEND_SERVICE=dev-davidshaevel-frontend
   ```

4. **Verify All Secrets**
   - Confirm you see 9 secrets in **Environment secrets** section
   - Environment page shows "9 secrets" count
   - Secret values are hidden (only shown when you set them)
   - No green "Updated" timestamp yet (secrets not used)

### Benefits of GitHub Environments Approach

✅ **Future-proof for production:**
- When adding prod: Create `prod` environment, same secret names, different values
- Clean separation: Dev and prod secrets completely isolated
- No name prefixes needed (avoid `DEV_AWS_ACCESS_KEY_ID` vs `PROD_AWS_ACCESS_KEY_ID`)

✅ **Deployment protection:**
- Can add required reviewers for prod deployments later
- Can restrict prod to main branch only
- GitHub tracks deployment history per environment

✅ **Architectural symmetry:**
- Terraform: `terraform/environments/dev/` and `terraform/environments/prod/`
- GitHub: `dev` environment and `prod` environment
- AWS: `dev-davidshaevel-*` resources and `prod-davidshaevel-*` resources
- Perfect alignment across infrastructure, CI/CD, and cloud resources

---

## Part 3: Verification Checklist

Before proceeding to create GitHub Actions workflows, verify:

- [ ] AWS IAM user exists: `dev-davidshaevel-github-actions`
- [ ] IAM policy attached with least-privilege resource scoping
- [ ] AWS access keys generated and saved securely
- [ ] GitHub `dev` environment created
- [ ] 9 environment secrets configured in `dev` environment
- [ ] All secret values copied exactly (no typos)
- [ ] Ready to create `.github/workflows/` files

---

## Security Best Practices

### AWS Access Keys

✅ **DO:**
- Rotate access keys every 90 days
- Monitor CloudTrail for unauthorized IAM user activity
- Delete old access keys after rotating
- Use separate IAM users for dev and prod

❌ **DON'T:**
- Commit access keys to Git (GitHub will detect and alert)
- Share access keys via email/Slack
- Reuse same keys across multiple repositories
- Leave unused access keys active

### GitHub Secrets

✅ **DO:**
- Use environment secrets (matches Terraform environments/)
- Create separate environments (dev, prod) with same secret names, different values
- Review who has admin access to repository and environments
- Monitor GitHub audit log for secret access
- Update environment secrets when rotating AWS keys
- Use protection rules for production environment

❌ **DON'T:**
- Print secrets in workflow logs (GitHub masks them, but don't try)
- Store secrets in workflow files or code
- Use repository secrets when you have multiple environments (use environment secrets instead)
- Use organization secrets unless needed across many repos

---

## Troubleshooting

### AWS Access Keys

**Issue:** Can't create access key - "Limit exceeded"
- **Cause:** IAM users can have maximum 2 access keys
- **Solution:** Delete an old/unused access key first

**Issue:** Forgot to save secret access key
- **Cause:** Secret only shown once during creation
- **Solution:** Delete the access key and create a new one

### GitHub Secrets

**Issue:** Secret not working in workflow
- **Cause:** Typo in secret name or value
- **Solution:** Double-check secret name matches workflow exactly
- **Solution:** Re-enter the secret value (no spaces/newlines)

**Issue:** Workflow can't access ECR/ECS
- **Cause:** IAM policy permissions insufficient
- **Solution:** Verify Terraform applied successfully
- **Solution:** Check CloudTrail for denied API calls

---

## Next Steps

After completing these manual steps:

1. ✅ Verify all secrets are configured
2. ➡️ Proceed to **Phase 2: Backend CI/CD Workflow**
3. Create `.github/workflows/backend-deploy.yml`
4. Test workflow with a sample deployment

---

## Reference

**Terraform Resources:**
- Module: `terraform/modules/cicd-iam/`
- Environment: `terraform/environments/dev/main.tf`
- Outputs: `terraform/environments/dev/outputs.tf`

**AWS Resources:**
- IAM User ARN: `arn:aws:iam::108581769167:user/cicd/dev-davidshaevel-github-actions`
- IAM Policy ARN: `arn:aws:iam::108581769167:policy/cicd/dev-davidshaevel-github-actions-deployment`

**GitHub:**
- Repository: `davidshaevel/davidshaevel-platform`
- Environment: `dev` (Settings → Environments → dev)
- Secrets location: Settings → Environments → dev → Environment secrets

**Related:**
- Linear Issue: TT-31
- Agenda: `docs/2025-11-03_cicd_implementation_agenda.md`
- Phase: 1, Blocks 1.2-1.3

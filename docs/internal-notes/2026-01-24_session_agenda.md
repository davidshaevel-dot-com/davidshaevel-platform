# Work Session Agenda - Saturday, January 24, 2026

**Project:** DavidShaevel.com Platform
**Focus:** Vercel Migration & AWS Cost Optimization - Phase 1 Completion
**Branch:** `vercel-migration`

---

## Session Overview

Continue from where we left off: complete TT-91 by deploying the backend to Vercel, then proceed to custom domain configuration.

---

## Carry-Over from Yesterday

### TT-91: Deploy to Vercel (IN PROGRESS)

**Frontend:** DONE
- URL: https://davidshaevel-frontend.vercel.app
- Production branch: `vercel-migration`

**Backend:** TO DO

---

## Today's Tasks

### 1. Complete TT-91: Deploy Backend to Vercel

**Steps:**

1. Open https://vercel.com/new/davidshaevel-dot-com

2. Import repository:
   - Repository: `davidshaevel-platform`
   - Root Directory: `backend`
   - Framework Preset: `Other`

3. Configure Production Branch:
   - Change from `main` to `vercel-migration`

4. Add Environment Variables:
   ```
   DATABASE_URL=postgresql://neondb_owner:<password>@ep-patient-glade-ahwwxh49-pooler.c-3.us-east-1.aws.neon.tech/neondb?sslmode=require
   NODE_ENV=production
   RESEND_API_KEY=<from .envrc>
   CONTACT_FORM_TO=hello@davidshaevel.com
   CONTACT_FORM_FROM=hello@davidshaevel.com
   ```

5. Deploy and verify:
   ```bash
   # Test health endpoint
   curl https://<backend-domain>.vercel.app/api/health

   # Test projects endpoint
   curl https://<backend-domain>.vercel.app/api/projects
   ```

**Acceptance Criteria:**
- Backend deployed to Vercel
- Health check returns 200 OK
- Database connectivity confirmed
- Contact form API working

---

### 2. Start TT-92: Configure Custom Domain

**After backend is deployed:**

1. Configure custom domain in Vercel:
   - Frontend: `davidshaevel.com` and `www.davidshaevel.com`
   - Backend: API routes at `/api/*`

2. Update Cloudflare DNS:
   - Point to Vercel instead of CloudFront
   - Configure CNAME records

3. Verify SSL certificates

4. Test all endpoints:
   - https://davidshaevel.com/
   - https://davidshaevel.com/api/health
   - https://davidshaevel.com/api/projects
   - https://davidshaevel.com/api/contact (POST)

---

### 3. Optional: Begin TT-93 (AWS Decommissioning)

**Only if Vercel is fully verified working:**

1. Plan decommissioning order:
   - Stop ECS services
   - Disable NAT Gateways
   - Update CloudFront to Vercel origin

2. Keep RDS running initially for fallback

---

## Quick Reference

### Vercel Team
- Name: `davidshaevel-dot-com`
- Plan: Free tier
- Dashboard: https://vercel.com/davidshaevel-dot-com

### Neon Database
- Project: `neondb`
- Region: `us-east-1`
- Connection: `ep-patient-glade-ahwwxh49-pooler.c-3.us-east-1.aws.neon.tech`

### Environment Variables Location
- `.envrc` - Contains NEON_DATABASE_URL, RESEND_API_KEY

### Git Worktree
```bash
cd /Users/dshaevel/workspace-ds/davidshaevel-platform/vercel-migration
```

---

## Success Criteria for Today

- [ ] Backend deployed to Vercel
- [ ] All API endpoints working
- [ ] Custom domain configured (optional)
- [ ] TT-91 marked as Done in Linear

---

**Session Created:** January 23, 2026

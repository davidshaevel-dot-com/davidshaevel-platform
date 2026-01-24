# Linear Project Update - Vercel Migration & AWS Cost Optimization

**Copy/paste the content below into the Linear project update:**

---

## Project Update - January 23, 2026

### Summary

Started Phase 1 implementation. Completed Neon database setup and NestJS serverless adaptation. Frontend deployed to Vercel. Backend deployment in progress.

### Progress

**Completed:**
- TT-89: Set up Neon database (free tier) - DONE
- TT-90: Adapt NestJS backend for Vercel serverless - DONE

**In Progress:**
- TT-91: Deploy to Vercel - Frontend complete, backend pending

### What We Built

**Database Layer:**
- Neon PostgreSQL 15 on free tier
- Dual-mode TypeORM config (Neon for Vercel, RDS for AWS)
- Operational scripts: `neon-init.sh`, `neon-validate.sh`

**Backend Adaptation:**
- Vercel serverless entry point using `@vendia/serverless-express`
- Cold start optimization with server caching
- Maintains AWS ECS compatibility

**Frontend Deployment:**
- Live at: https://davidshaevel-frontend.vercel.app
- Next.js 16.1.4 (upgraded for CVE fix)
- Auto-deploy from `vercel-migration` branch

### Key Decisions

1. Created dedicated `vercel-migration` git worktree for isolated development
2. Used `@vendia/serverless-express` for minimal NestJS changes
3. Environment-driven database selection (`DATABASE_URL` vs individual params)

### Blockers/Issues Resolved

| Issue | Resolution |
|-------|------------|
| CVE-2025-66478 in Next.js | Upgraded 16.0.1 → 16.1.4 |
| Vercel CLI incompatible with Node 24 | Used web UI |
| Shell arithmetic failed with `set -e` | Changed syntax |

### Cost Impact

| Item | Before | After |
|------|--------|-------|
| Monthly AWS | ~$118-126 | ~$0 |
| Vercel + Neon | $0 | ~$5-15 |

### Next Steps (Tomorrow)

1. Complete TT-91: Deploy backend to Vercel
2. Start TT-92: Configure custom domain
3. Begin TT-93: AWS decommissioning

### Commits

- `0515f16` - feat(TT-89, TT-90): Add Neon database support and Vercel serverless adapter
- `cac47ec` - fix: Update Next.js to 16.1.4 to address CVE-2025-66478
- `c4fdfd2` - chore: Trigger Vercel deployment

---

**Lines: ~70 (under 180 limit)**

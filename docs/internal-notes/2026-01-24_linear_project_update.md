# Linear Project Update - Vercel Migration & AWS Cost Optimization

**Copy/paste the content below into the Linear project update:**

---

## Project Update - January 24, 2026

### Summary

Phase 1 complete. davidshaevel.com is now fully served by Vercel with Neon PostgreSQL. DNS switched from AWS CloudFront. All endpoints verified working.

### Progress (2-Day Sprint: Jan 23-24)

**Completed (7 issues):**
- TT-89: Neon database setup (free tier PostgreSQL 15)
- TT-90: NestJS backend adapted for Vercel serverless
- TT-91: Frontend + backend deployed to Vercel
- TT-92: Custom domain configured with DNS switch
- TT-93: Environment variables configured
- TT-100: DNS switch script created (Vercel ↔ AWS)
- TT-105: Production cutover executed

**Remaining (9 issues in Phase 2):**
- TT-94: End-to-end testing
- TT-95: Add dev_activated Terraform variable
- TT-96-97: Activation/deactivation scripts
- TT-98-99: Database sync scripts
- TT-101-103: Testing cycles
- TT-104: Documentation updates
- TT-106: Deactivate AWS to pilot light

### Architecture (Current)

```
DNS (Cloudflare)
    │
    ▼
Vercel (Frontend)
    │
    ├── Next.js Pages (davidshaevel.com)
    │
    └── /api/* rewrite ──→ Vercel (Backend)
                                │
                                └── NestJS Serverless
                                        │
                                        ▼
                                  Neon PostgreSQL
```

### Key Technical Decisions

1. **Native Vercel handler** instead of `@vendia/serverless-express` (AWS Lambda format incompatible)
2. **API rewrites** via `frontend/vercel.json` for single-domain routing
3. **DNS automation** via `scripts/vercel-dns-switch.sh` using Cloudflare API

### Scripts Created

| Script | Purpose |
|--------|---------|
| `scripts/neon-init.sh` | Initialize Neon schema |
| `scripts/neon-validate.sh` | 19 database checks |
| `scripts/vercel-dns-switch.sh` | Switch DNS between Vercel ↔ AWS |

### Cost Impact

| Item | Before | After |
|------|--------|-------|
| Monthly AWS | ~$118-126 | ~$0 (still running) |
| Vercel + Neon | $0 | ~$5-15 |
| **Savings** | | **~$100+/mo** |

### Rollback Plan

```bash
# Switch DNS back to AWS CloudFront
./scripts/vercel-dns-switch.sh --to-aws
```

### Next Steps (Phase 2)

Focus shifts to AWS pilot light mode:
1. End-to-end testing of Vercel deployment
2. Add `dev_activated` conditional to Terraform
3. Create activation/deactivation scripts
4. Create database sync scripts (Neon ↔ RDS)
5. Test activation/deactivation cycles
6. Deactivate AWS dev to pilot light

---

**Lines: ~85 (under 180 limit)**

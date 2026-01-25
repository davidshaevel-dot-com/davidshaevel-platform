# Work Session Summary - Saturday, January 24, 2026

**Project:** DavidShaevel.com Platform
**Focus:** Vercel Migration & AWS Cost Optimization - Phase 1 Completion
**Branch:** `vercel-migration`

---

## Session Overview

Completed Phase 1 of the Vercel migration. Backend deployed to Vercel, custom domain configured, DNS switched from AWS CloudFront to Vercel. davidshaevel.com is now fully served by Vercel.

---

## Completed Today

### TT-91: Deploy to Vercel (DONE)

**Backend Deployment:**
- Created `davidshaevel-backend` project in Vercel
- Configured environment variables (DATABASE_URL, NODE_ENV, RESEND_API_KEY, etc.)
- Fixed two deployment issues:
  1. Vercel auto-detected NestJS and used wrong entry point → Set `framework: null`
  2. `@vendia/serverless-express` expected AWS Lambda format → Switched to Vercel native `IncomingMessage`/`ServerResponse`
- Backend live at: https://davidshaevel-backend.vercel.app

**Verified Endpoints:**
- `/api/health` → 200 OK, database connected
- `/api/projects` → 200 OK

### TT-92: Custom Domain + DNS Switch (DONE)

- Added `davidshaevel.com` and `www.davidshaevel.com` to frontend Vercel project
- Created `frontend/vercel.json` with API rewrites (`/api/*` → backend project)
- Created `scripts/vercel-dns-switch.sh`:
  - Automates Cloudflare DNS switching between Vercel and AWS CloudFront
  - Supports `--to-vercel`, `--to-aws`, `--status`, `--dry-run`
  - Handles root domain type change (CNAME ↔ A record)
- Executed DNS switch:
  - Root: CNAME `dbaz91yl33r82.cloudfront.net` → A `216.198.79.1`
  - WWW: CNAME CloudFront → CNAME `2d7df72c42ce62a7.vercel-dns-017.com.`
- SSL certificate provisioned by Vercel

### Additional Issues Completed

- **TT-93:** Configure Vercel environment variables (done as part of TT-91)
- **TT-100:** Create DNS switch script (done as `scripts/vercel-dns-switch.sh`)
- **TT-105:** Production cutover: Switch DNS to Vercel (executed via script)

---

## Commits

| Hash | Message |
|------|---------|
| `f1054e3` | docs: Add session summary and agenda for Vercel migration |
| `abb7940` | fix: Disable Vercel framework detection for serverless backend |
| `e289b81` | fix: Use Vercel native request/response format |
| `9e0c775` | feat: Add Vercel rewrites for API routing |
| `f8dfc40` | feat(TT-92): Add Vercel DNS switch script |

---

## Files Created/Modified

### New Files
- `frontend/vercel.json` - API rewrites to backend project
- `scripts/vercel-dns-switch.sh` - DNS switch between Vercel and AWS

### Modified Files
- `backend/api/index.ts` - Switched from AWS Lambda to Vercel native handler
- `backend/vercel.json` - Added `framework: null`, catch-all route
- `README.md` - Updated milestones and session list
- `CLAUDE.md` - Updated completed issues
- `CLAUDE.local.md` - Added session notes

---

## Issues Encountered & Resolved

| Issue | Resolution |
|-------|------------|
| Vercel auto-detected NestJS | Set `framework: null` in vercel.json |
| `@vendia/serverless-express` wrong format | Replaced with native Node.js request/response |
| SSL cert not ready immediately | Waited ~30 seconds for Vercel provisioning |
| Cloudflare API token appeared invalid | Token was valid; initial source command conflicted |

---

## Current State

davidshaevel.com is now fully served by Vercel:
- **Frontend:** Next.js on Vercel (auto-deploy from vercel-migration branch)
- **Backend:** NestJS serverless functions on Vercel
- **Database:** Neon PostgreSQL (free tier)
- **DNS:** Cloudflare → Vercel (switchable via script)
- **AWS:** Still running but not receiving traffic

---

## What Remains

### Phase 2: AWS Pilot Light Mode
- TT-94: End-to-end testing
- TT-95: Add `dev_activated` variable to Terraform
- TT-96-97: Activation/deactivation scripts
- TT-98-99: Database sync scripts
- TT-101-103: Testing cycles
- TT-104: Documentation updates
- TT-106: Deactivate AWS to pilot light

---

**Session Created:** January 24, 2026
**Last Updated:** January 24, 2026

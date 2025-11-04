# TT-24 Implementation Plan - CloudFront CDN with Cloudflare DNS

**Issue:** TT-24 - Implement CloudFront CDN and custom domain
**Phase:** Step 10 of 10-step implementation plan (FINAL STEP)
**DNS Approach:** Cloudflare (existing) - NO Route53 migration
**Created:** October 26, 2025

---

## Architecture Decision: Keep Cloudflare DNS

**Decision:** Continue using Cloudflare for DNS instead of migrating to Route53

**Rationale:**
- Zero migration risk (DNS already working in Cloudflare)
- No DNS downtime risk
- Keep Cloudflare features (DDoS protection, analytics)
- Cloudflare CNAME flattening supports apex domain
- Cost savings (~$0.50/month Route53 hosted zone)
- Industry standard pattern (CloudFront + external DNS)
- Separation of concerns (AWS infrastructure, Cloudflare DNS)

---

## Step 10 Deliverables

### 1. CloudFront Distribution

**Resources to Create:**
- CloudFront distribution with ALB origin
- Origin request policy for dynamic content
- Cache policy for static content
- Custom domain configuration (CNAME aliases)
- SSL/TLS configuration with ACM certificate

**Configuration:**
- **Origin:** ALB DNS from compute module output
- **Alternate Domain Names (CNAMEs):**
  - `davidshaevel.com`
  - `www.davidshaevel.com`
- **Viewer Protocol Policy:** Redirect HTTP to HTTPS
- **Allowed HTTP Methods:** GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE
- **Compress Objects:** Enabled
- **Price Class:** PriceClass_100 (US, Canada, Europe)

**Cache Behaviors:**
- **Default (/):** Forward to frontend
  - Cache policy: Optimized for static content
  - TTL: 24 hours for static assets
- **Path Pattern (/api/*):** Forward to backend
  - Cache policy: Managed-CachingDisabled (no caching for API)
  - Origin request policy: Managed-AllViewer (forward all headers)

### 2. ACM Certificate

**Resources to Create:**
- ACM certificate request for custom domains
- Certificate validation method: DNS
- Domains to include:
  - `davidshaevel.com`
  - `*.davidshaevel.com` (wildcard for www)

**Process:**
1. Request certificate in `us-east-1` (required for CloudFront)
2. Use DNS validation method
3. Terraform outputs validation CNAME records
4. **Manual step:** Add validation records to Cloudflare
5. Wait for certificate validation (usually < 5 minutes)
6. Attach validated certificate to CloudFront distribution

**Important:** Certificate MUST be in us-east-1 region for CloudFront, regardless of where other resources are deployed.

### 3. Cloudflare DNS Configuration (Manual)

**Records to Add in Cloudflare UI:**

**ACM Certificate Validation (temporary):**
- Type: CNAME
- Name: `_<random>.davidshaevel.com`
- Target: `_<random>.acm-validations.aws.`
- TTL: Auto
- Proxy status: DNS only (gray cloud)
- **Note:** Terraform will output exact record values

**CloudFront Distribution (permanent):**
- Type: CNAME
- Name: `davidshaevel.com` (apex)
- Target: `<distribution-id>.cloudfront.net`
- TTL: Auto
- Proxy status: **DNS only (gray cloud)** - Important!

- Type: CNAME
- Name: `www`
- Target: `<distribution-id>.cloudfront.net`
- TTL: Auto
- Proxy status: DNS only (gray cloud)

**Important:** Use DNS only mode (gray cloud) to avoid double CDN (Cloudflare + CloudFront)

### 4. Terraform Module Structure

**Create:** `terraform/modules/cdn/`

**Files:**
- `main.tf` - CloudFront distribution, ACM certificate
- `variables.tf` - Configuration inputs
- `outputs.tf` - CloudFront domain, certificate details
- `README.md` - Usage documentation

**Key Variables:**
- `domain_name` - Primary domain (davidshaevel.com)
- `alternate_domain_names` - Additional domains (www.davidshaevel.com)
- `alb_dns_name` - Origin from compute module
- `enable_ipv6` - IPv6 support (default: true)
- `price_class` - CloudFront edge locations
- `web_acl_id` - Optional WAF ACL (for future)

**Key Outputs:**
- `cloudfront_domain_name` - Distribution DNS name
- `cloudfront_distribution_id` - For cache invalidation
- `cloudfront_hosted_zone_id` - For potential future use
- `acm_certificate_arn` - Certificate ARN
- `acm_certificate_validation_records` - CNAME records to add to Cloudflare

---

## Implementation Steps

### Phase 1: Module Development

1. **Create CDN module structure**
   ```bash
   mkdir -p terraform/modules/cdn
   touch terraform/modules/cdn/{main.tf,variables.tf,outputs.tf,README.md}
   ```

2. **Implement ACM certificate**
   - Request certificate in us-east-1
   - DNS validation method
   - Include apex and wildcard domains
   - Output validation records

3. **Implement CloudFront distribution**
   - Configure origin (ALB)
   - Set up cache behaviors
   - Configure HTTPS settings
   - Add custom domain names
   - Attach ACM certificate (depends_on validation)

4. **Create comprehensive outputs**
   - CloudFront domain name
   - Distribution ID
   - ACM validation CNAME records (for Cloudflare)

### Phase 2: Environment Integration

1. **Update dev environment**
   - Add CDN module to `terraform/environments/dev/main.tf`
   - Pass ALB DNS from compute module
   - Configure domain names
   - Add new outputs

2. **Testing approach**
   - Run `terraform validate`
   - Run `terraform plan` (certificate will be pending validation)
   - Run `terraform apply`
   - **Pause for manual step:** Add validation records to Cloudflare
   - Wait for certificate validation
   - **Pause for manual step:** Add CloudFront CNAME records to Cloudflare
   - Test DNS propagation
   - Test HTTPS access

### Phase 3: DNS Configuration (Manual)

1. **Add ACM validation records**
   - Copy records from Terraform output
   - Add to Cloudflare DNS (gray cloud)
   - Wait for validation (check AWS Certificate Manager console)

2. **Add CloudFront CNAMEs**
   - Copy CloudFront domain from Terraform output
   - Add `davidshaevel.com` CNAME → CloudFront (gray cloud)
   - Add `www.davidshaevel.com` CNAME → CloudFront (gray cloud)
   - Wait for DNS propagation (~5-10 minutes)

3. **Verification**
   ```bash
   # Check DNS propagation
   dig davidshaevel.com
   dig www.davidshaevel.com

   # Test HTTPS
   curl -I https://davidshaevel.com
   curl -I https://www.davidshaevel.com

   # Test API routing
   curl -I https://davidshaevel.com/api/health
   ```

---

## Cost Estimate

**Monthly Costs (Low Traffic):**
- CloudFront requests: ~$1-2/month
- CloudFront data transfer: ~$1-2/month
- ACM Certificate: $0 (free)
- Route53: $0 (using Cloudflare instead)
- **Total Step 10:** ~$2-4/month

**Previous Total:** ~$115-120/month
**New Total:** ~$117-124/month

---

## Testing Strategy

### Local Testing (Before DNS)

```bash
# Test CloudFront distribution with distribution domain
curl -I https://<distribution-id>.cloudfront.net

# Test with custom domain (after DNS)
curl -I https://davidshaevel.com

# Test API routing
curl -I https://davidshaevel.com/api/health

# Test HTTP → HTTPS redirect
curl -I http://davidshaevel.com
```

### Browser Testing

1. Visit `https://davidshaevel.com`
2. Verify HTTPS certificate (should show valid)
3. Check frontend loads
4. Test API endpoint: `https://davidshaevel.com/api/health`
5. Verify HTTP redirects to HTTPS

### CloudFront Cache Testing

```bash
# Check CloudFront headers
curl -I https://davidshaevel.com

# Look for X-Cache: Hit from cloudfront (cached)
# or X-Cache: Miss from cloudfront (not cached yet)

# Clear cache if needed
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"
```

---

## Documentation Requirements

1. **Module README** (`terraform/modules/cdn/README.md`)
   - Usage examples
   - Variable descriptions
   - Output descriptions
   - Cloudflare DNS setup instructions
   - Troubleshooting guide

2. **Manual Steps Document**
   - How to add ACM validation records to Cloudflare
   - How to add CloudFront CNAME records to Cloudflare
   - Screenshots or step-by-step guide

3. **Update Main README**
   - Note about Cloudflare DNS requirement
   - Link to manual setup instructions

---

## Known Limitations & Future Considerations

### Current Approach (Cloudflare DNS + Manual Updates)

**Pros:**
- ✅ Simple Terraform code
- ✅ No Cloudflare API token required
- ✅ Clear separation: IaC for AWS, manual for DNS
- ✅ DNS changes are infrequent

**Cons:**
- ❌ Manual steps required (not fully automated)
- ❌ DNS records not in Terraform state

### Future Enhancement Option (Cloudflare Terraform Provider)

If we want fully automated DNS management:

1. Add Cloudflare provider to Terraform
2. Manage DNS records in Terraform
3. Requires Cloudflare API token
4. Fully automated, no manual steps

**Implementation later if desired:**
```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

resource "cloudflare_record" "apex" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = aws_cloudfront_distribution.main.domain_name
  type    = "CNAME"
  proxied = false  # gray cloud
}
```

---

## Acceptance Criteria

### Infrastructure
- ✅ CloudFront distribution created and deployed
- ✅ ACM certificate requested and validated
- ✅ CloudFront uses custom domains (davidshaevel.com, www.davidshaevel.com)
- ✅ HTTPS enabled with valid certificate
- ✅ HTTP redirects to HTTPS
- ✅ Cache behaviors configured correctly

### DNS
- ✅ ACM validation records added to Cloudflare
- ✅ CloudFront CNAME records added to Cloudflare
- ✅ DNS resolves correctly (dig test passes)
- ✅ Cloudflare proxy disabled (gray cloud)

### Testing
- ✅ `terraform validate` passes
- ✅ `terraform plan` shows expected resources
- ✅ `terraform apply` succeeds
- ✅ https://davidshaevel.com loads correctly
- ✅ https://www.davidshaevel.com loads correctly
- ✅ API routing works: https://davidshaevel.com/api/health
- ✅ HTTP → HTTPS redirect works

### Documentation
- ✅ Module README with Cloudflare setup instructions
- ✅ Manual steps documented clearly
- ✅ Troubleshooting guide included
- ✅ Main README updated

---

## Implementation Timeline

**Estimated Effort:** 4-6 hours

1. **Module Development:** 2-3 hours
   - CDN module code
   - Testing and validation

2. **Integration & Deployment:** 1-2 hours
   - Environment integration
   - Terraform apply
   - Certificate validation wait time

3. **DNS Configuration:** 30 minutes
   - Add Cloudflare records
   - DNS propagation wait time

4. **Documentation:** 1 hour
   - Module README
   - Manual setup guide
   - Update main docs

---

## Next Steps After TT-24

Once CDN is deployed (Step 10 complete = 100% infrastructure):

1. **TT-18:** Build Next.js frontend application
2. **TT-19:** Build Nest.js backend API
3. **TT-23:** Create ECR repositories and deploy real containers
4. Enable HTTPS on ALB (update compute module with ACM cert from CDN module)
5. Remove nginx placeholder images

---

**🎯 This completes the 10-step infrastructure implementation plan!**

# CDN Module - CloudFront Distribution with Custom Domain

This module creates an AWS CloudFront distribution with ACM SSL certificate for custom domain support. It's designed to work with Cloudflare DNS (no Route53 migration required).

## Architecture

```
Internet
    │
    ▼
CloudFront Distribution (Global CDN)
    │
    ├── Cache: Static content (/, /assets/*)
    ├── No Cache: API endpoints (/api/*)
    │
    ▼
Application Load Balancer (Origin)
    │
    ├── Frontend (port 3000)
    └── Backend (port 3001)
```

## Features

- **Global Content Delivery**: CloudFront edge locations in US, Canada, and Europe (PriceClass_100)
- **SSL/TLS**: ACM certificate with DNS validation for custom domains
- **Custom Domain Support**: Primary domain + alternate domains (e.g., www subdomain)
- **Intelligent Caching**:
  - Default behavior: Optimized caching for static content (frontend)
  - `/api/*` path: No caching for dynamic API endpoints
- **HTTP to HTTPS**: Automatic redirect for all traffic
- **IPv6 Support**: Enabled by default
- **Compression**: Automatic gzip/brotli compression enabled
- **Error Pages**: Custom error responses for 502, 503, 504

## Important: Cloudflare DNS Integration

This module **outputs DNS validation records** that must be added to Cloudflare DNS manually. The module does NOT manage Cloudflare DNS directly to keep the Terraform configuration simple and avoid requiring Cloudflare API tokens.

### Why Cloudflare DNS (Not Route53)?

**Decision**: Continue using Cloudflare for DNS instead of migrating to Route53

**Benefits**:
- ✅ Zero migration risk (DNS already working)
- ✅ No DNS downtime risk
- ✅ Keep Cloudflare features (DDoS protection, analytics, page rules)
- ✅ Cloudflare CNAME flattening supports apex domains
- ✅ Cost savings (~$0.50/month for Route53 hosted zone)
- ✅ Industry standard pattern (CloudFront + external DNS provider)
- ✅ Separation of concerns (AWS infrastructure, Cloudflare DNS)

## Requirements

- Terraform >= 1.13.0
- AWS Provider >= 6.18.0
- AWS Provider alias `aws.us_east_1` (ACM certificates for CloudFront MUST be in us-east-1)
- Existing Application Load Balancer (ALB)
- Access to Cloudflare DNS for manual configuration

## Usage

### Basic Configuration

```hcl
module "cdn" {
  source = "../../modules/cdn"

  # Required: Provider for us-east-1 ACM certificate
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  # Environment configuration
  environment  = "dev"
  project_name = "myproject"

  # Domain configuration
  domain_name            = "example.com"
  alternate_domain_names = ["www.example.com"]

  # ALB origin (from compute module output)
  alb_dns_name = module.compute.alb_dns_name
}
```

### Complete Example with All Options

```hcl
module "cdn" {
  source = "../../modules/cdn"

  # Required: Provider for us-east-1 ACM certificate
  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  # Environment configuration
  environment  = "dev"
  project_name = "myproject"

  # Domain configuration
  domain_name            = "example.com"
  alternate_domain_names = ["www.example.com", "app.example.com"]

  # ALB origin
  alb_dns_name = "my-alb-123456789.us-east-1.elb.amazonaws.com"

  # CloudFront configuration
  enable_ipv6         = true
  price_class         = "PriceClass_100" # US, Canada, Europe
  default_root_object = "index.html"

  # Optional: CloudFront access logs
  logging_bucket = "my-logs-bucket.s3.amazonaws.com"
  logging_prefix = "cloudfront/"

  # Optional: AWS WAF Web ACL
  web_acl_id = "arn:aws:wafv2:us-east-1:123456789012:global/webacl/..."
}
```

### Provider Configuration

The module requires an AWS provider configured for us-east-1 region (CloudFront certificate requirement):

```hcl
# In your root terraform configuration
provider "aws" {
  region = "us-east-1" # or your preferred region
}

# Additional provider for CloudFront ACM certificates
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
```

## Deployment Process

### Step 1: Terraform Apply

```bash
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

**Note**: The apply will succeed, but the ACM certificate will be in `PENDING_VALIDATION` status until you complete Step 2.

### Step 2: ACM Certificate Validation (Manual - Cloudflare)

After `terraform apply`, retrieve the validation records:

```bash
terraform output acm_certificate_validation_records
```

**Output example**:
```json
[
  {
    "name": "_abc123.example.com",
    "type": "CNAME",
    "value": "_xyz789.acm-validations.aws."
  },
  {
    "name": "_def456.example.com",
    "type": "CNAME",
    "value": "_uvw012.acm-validations.aws."
  }
]
```

**Add these records to Cloudflare DNS**:

1. Log in to Cloudflare Dashboard
2. Select your domain
3. Go to **DNS** → **Records**
4. Click **Add record**
5. For each validation record:
   - **Type**: CNAME
   - **Name**: Copy from output (e.g., `_abc123`)
   - **Target**: Copy from output (e.g., `_xyz789.acm-validations.aws.`)
   - **TTL**: Auto
   - **Proxy status**: **DNS only** (gray cloud) ← **IMPORTANT**
6. Click **Save**

**Wait for validation** (~5-10 minutes):

```bash
# Check certificate status
terraform output acm_certificate_status

# Or check in AWS Console
# ACM → Certificates → us-east-1 region
```

When status changes from `PENDING_VALIDATION` to `ISSUED`, proceed to Step 3.

### Step 3: CloudFront CNAME Records (Manual - Cloudflare)

After certificate is validated, retrieve CloudFront domain:

```bash
terraform output cloudflare_cname_records
```

**Output example**:
```json
{
  "cloudfront_domain": "d123abc456def.cloudfront.net",
  "records": [
    {
      "name": "@",
      "type": "CNAME",
      "value": "d123abc456def.cloudfront.net",
      "note": "Use DNS only mode (gray cloud) in Cloudflare"
    },
    {
      "name": "www",
      "type": "CNAME",
      "value": "d123abc456def.cloudfront.net",
      "note": "Use DNS only mode (gray cloud) in Cloudflare"
    }
  ]
}
```

**Add these records to Cloudflare DNS**:

1. In Cloudflare Dashboard → DNS → Records
2. **For apex domain** (example.com):
   - **Type**: CNAME
   - **Name**: @ (or just your domain name)
   - **Target**: `d123abc456def.cloudfront.net` (from output)
   - **TTL**: Auto
   - **Proxy status**: **DNS only** (gray cloud) ← **IMPORTANT**
   - Click **Save**

3. **For www subdomain** (www.example.com):
   - **Type**: CNAME
   - **Name**: www
   - **Target**: `d123abc456def.cloudfront.net` (from output)
   - **TTL**: Auto
   - **Proxy status**: **DNS only** (gray cloud) ← **IMPORTANT**
   - Click **Save**

**⚠️ CRITICAL: Use DNS Only Mode (Gray Cloud)**

You MUST use "DNS only" mode (gray cloud) in Cloudflare for these records. If you use "Proxied" mode (orange cloud), you'll have double CDN (Cloudflare + CloudFront), which causes issues:
- Conflicting SSL certificates
- Double caching layers
- Increased latency
- Unexpected behavior

### Step 4: Verify DNS Propagation

Wait for DNS propagation (~5-10 minutes), then verify:

```bash
# Check DNS resolution
dig example.com
dig www.example.com

# Expected result: Should resolve to CloudFront distribution
# example.com.  300  IN  CNAME  d123abc456def.cloudfront.net.
```

### Step 5: Test HTTPS Access

```bash
# Test custom domain
curl -I https://example.com

# Expected: 200 OK (or 502 if using placeholder images)

# Test www subdomain
curl -I https://www.example.com

# Test API routing
curl -I https://example.com/api/health

# Test HTTP → HTTPS redirect
curl -I http://example.com
# Expected: 301 or 302 redirect to https://
```

## Cache Behavior

### Default Behavior (Frontend - `/`)

- **Cached Methods**: GET, HEAD, OPTIONS
- **Allowed Methods**: All (GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE)
- **Cache Policy**: AWS Managed `CachingOptimized`
- **Compression**: Enabled
- **Viewer Protocol**: Redirect HTTP to HTTPS

**Best For**: Static assets, HTML pages, images, CSS, JavaScript

### Ordered Behavior (Backend API - `/api/*`)

- **Cached Methods**: GET, HEAD (but cache is disabled)
- **Allowed Methods**: All (GET, HEAD, OPTIONS, PUT, POST, PATCH, DELETE)
- **Cache Policy**: AWS Managed `CachingDisabled` (no caching)
- **Origin Request Policy**: AWS Managed `AllViewer` (forward all headers/cookies)
- **Compression**: Enabled
- **Viewer Protocol**: Redirect HTTP to HTTPS

**Best For**: Dynamic API endpoints, authentication, user-specific content

## Outputs

| Output | Description |
|--------|-------------|
| `cloudfront_distribution_id` | CloudFront distribution ID (use for cache invalidation) |
| `cloudfront_domain_name` | CloudFront domain (e.g., d123abc.cloudfront.net) |
| `cloudfront_status` | Distribution status (Deployed, InProgress) |
| `acm_certificate_arn` | ACM certificate ARN |
| `acm_certificate_status` | Certificate status (PENDING_VALIDATION, ISSUED) |
| `acm_certificate_validation_records` | DNS validation records to add to Cloudflare |
| `cloudflare_cname_records` | CNAME records to add to Cloudflare |
| `custom_domain_urls` | Custom domain URLs (after DNS configured) |
| `cache_invalidation_command` | AWS CLI command to invalidate cache |

## Cache Invalidation

To invalidate CloudFront cache (after deploying new code):

```bash
# Get the invalidation command
terraform output cache_invalidation_command

# Or manually
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/*"

# Invalidate specific paths
aws cloudfront create-invalidation \
  --distribution-id <DISTRIBUTION_ID> \
  --paths "/index.html" "/assets/*"
```

**Note**: First 1,000 invalidation paths per month are free, then $0.005 per path.

## Cost Estimate

**Monthly costs** (low traffic, estimated):

| Resource | Cost | Notes |
|----------|------|-------|
| CloudFront Requests | ~$1-2 | First 10M requests free tier |
| CloudFront Data Transfer | ~$1-2 | First 1TB outbound free tier |
| ACM Certificate | $0 | Free for CloudFront |
| Route53 Hosted Zone | $0 | Using Cloudflare instead |
| **Total** | **~$2-4/month** | Scales with traffic |

**Higher traffic** (100K daily visitors):
- CloudFront: ~$10-20/month
- Data transfer: ~$10-30/month
- **Total**: ~$20-50/month

## Troubleshooting

### Certificate Stuck in PENDING_VALIDATION

**Symptoms**: ACM certificate shows `PENDING_VALIDATION` status after 30+ minutes.

**Causes**:
- DNS validation records not added to Cloudflare
- DNS validation records incorrect (typo in name or value)
- DNS validation records have Proxy enabled (orange cloud)

**Solution**:
1. Verify records in Cloudflare match Terraform output exactly
2. Ensure records use "DNS only" mode (gray cloud)
3. Check DNS propagation: `dig _abc123.example.com CNAME`
4. Wait up to 30 minutes for AWS to detect validation

### Custom Domain Returns 403 Forbidden

**Symptoms**: `https://example.com` returns 403 error, but `https://d123abc.cloudfront.net` works.

**Causes**:
- DNS records not added to Cloudflare
- DNS records point to wrong CloudFront distribution
- Certificate not validated

**Solution**:
1. Verify CloudFront distribution status: `terraform output cloudfront_status` (should be "Deployed")
2. Verify certificate status: `terraform output acm_certificate_status` (should be "ISSUED")
3. Verify DNS records in Cloudflare match CloudFront domain from output
4. Wait for DNS propagation (5-10 minutes)

### Custom Domain Returns 502 Bad Gateway

**Symptoms**: `https://example.com` returns 502 error.

**Causes**:
- ALB origin is unhealthy
- ALB target groups have no healthy targets
- Using placeholder container images (nginx) without health endpoints

**Solution**:
1. Check ALB target health in AWS Console (EC2 → Target Groups)
2. Verify ECS tasks are running: `aws ecs list-tasks --cluster <CLUSTER_NAME>`
3. Check ALB health checks are passing
4. If using placeholder images, 502 is expected until real application is deployed

### DNS Not Resolving to CloudFront

**Symptoms**: `dig example.com` doesn't return CloudFront domain.

**Causes**:
- CNAME records not added to Cloudflare
- DNS propagation delay
- Records have Proxy enabled (orange cloud) - Cloudflare is intercepting

**Solution**:
1. Verify CNAME records exist in Cloudflare
2. Verify records use "DNS only" mode (gray cloud)
3. Wait for DNS propagation (can take up to 10 minutes)
4. Test with specific DNS server: `dig @8.8.8.8 example.com`

### CloudFront Returns Cloudflare Error Page

**Symptoms**: Cloudflare error page or Cloudflare branding visible.

**Cause**: CNAME records are using "Proxied" mode (orange cloud) instead of "DNS only" (gray cloud).

**Solution**:
1. In Cloudflare Dashboard → DNS → Records
2. Click on each CNAME record
3. Change **Proxy status** from "Proxied" (orange cloud) to "DNS only" (gray cloud)
4. Wait for DNS propagation

## Security Considerations

### HTTPS Only

All traffic is automatically redirected from HTTP to HTTPS using CloudFront viewer protocol policy.

### Origin Protection

CloudFront sends custom header `X-Custom-Header: <project_name>` to origin. Consider adding ALB listener rules to only accept requests with this header (prevents direct ALB access bypassing CloudFront).

### WAF Integration

For advanced security, attach AWS WAF Web ACL:

```hcl
module "cdn" {
  # ... other config ...
  web_acl_id = aws_wafv2_web_acl.main.arn
}
```

### TLS Configuration

- **Minimum TLS Version**: TLSv1.2_2021
- **SSL Support Method**: SNI only (Server Name Indication)
- **Origin Protocol**: HTTP only (ALB doesn't have HTTPS yet)
- **Viewer Protocol**: HTTPS with HTTP redirect

## Future Enhancements

### Option 1: Automated Cloudflare DNS (Future)

If you want fully automated DNS management, add Cloudflare Terraform provider:

```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Requires CLOUDFLARE_API_TOKEN environment variable
resource "cloudflare_record" "apex" {
  zone_id = var.cloudflare_zone_id
  name    = "@"
  value   = aws_cloudfront_distribution.main.domain_name
  type    = "CNAME"
  proxied = false # Gray cloud
}
```

### Option 2: Enable HTTPS to Origin

When you add ACM certificate to ALB (via compute module):

```hcl
# Update CDN module main.tf
origin_protocol_policy = "https-only"
```

### Option 3: S3 Origin for Static Assets

For improved performance, add S3 origin for static assets:

```hcl
origin {
  domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
  origin_id   = "s3-assets"
  
  s3_origin_config {
    origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
  }
}
```

## Variables

See [variables.tf](./variables.tf) for complete variable documentation.

## Module Structure

```
cdn/
├── main.tf          # CloudFront distribution and ACM certificate
├── variables.tf     # Input variables with validation
├── outputs.tf       # Output values including Cloudflare DNS instructions
├── versions.tf      # Terraform and provider version constraints
└── README.md        # This file
```

## References

- [AWS CloudFront Documentation](https://docs.aws.amazon.com/cloudfront/)
- [ACM Certificate Validation](https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html)
- [CloudFront Cache Policies](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/controlling-the-cache-key.html)
- [Cloudflare DNS Documentation](https://developers.cloudflare.com/dns/)

## Support

For issues or questions about this module, please check:
1. This README troubleshooting section
2. Terraform output messages
3. AWS CloudFront console (CloudFront → Distributions)
4. AWS ACM console (us-east-1 region only for CloudFront certificates)
5. Cloudflare DNS settings

---

**Last Updated**: October 26, 2025  
**Module Version**: 1.0.0  
**Terraform Version**: >= 1.13.0


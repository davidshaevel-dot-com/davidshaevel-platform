# Security Architecture

**Project:** DavidShaevel.com Platform  
**Date:** October 23, 2025  
**Author:** David Shaevel  
**Version:** 1.0

## Overview

This document outlines the security architecture and practices for the DavidShaevel.com platform, including network security, access control, data protection, and compliance considerations.

## Security Principles

1. **Defense in Depth:** Multiple layers of security controls
2. **Least Privilege:** Minimal permissions required for each component
3. **Encryption Everywhere:** Data encrypted at rest and in transit
4. **Zero Trust:** Never trust, always verify
5. **Audit Everything:** Comprehensive logging and monitoring
6. **Fail Securely:** Secure defaults, explicit allow lists

## Network Security

### Network Segmentation

**Three-Tier Architecture:**

1. **Public Tier** (DMZ)
   - Application Load Balancer
   - NAT Gateways
   - Bastion hosts (if needed)
   - Direct internet access

2. **Application Tier**
   - ECS containers (Frontend, Backend)
   - No direct internet access
   - Outbound via NAT Gateway
   - Isolated from database tier

3. **Data Tier**
   - RDS PostgreSQL
   - Completely isolated from internet
   - Accessible only from application tier
   - Multi-AZ for redundancy

### Security Groups (Stateful Firewall)

**Principle:** Deny all by default, explicit allows only

#### ALB Security Group
```hcl
# Inbound
- Allow TCP/80 from 0.0.0.0/0 (HTTP → HTTPS redirect)
- Allow TCP/443 from 0.0.0.0/0 (HTTPS)

# Outbound
- Allow TCP/3000 to frontend-sg (Frontend containers)
- Allow TCP/3001 to backend-sg (Backend containers)
```

#### Frontend Security Group
```hcl
# Inbound
- Allow TCP/3000 from alb-sg only

# Outbound
- Allow TCP/3001 to backend-sg (API calls)
- Allow TCP/443 to 0.0.0.0/0 (External APIs, CDNs)
```

#### Backend Security Group
```hcl
# Inbound
- Allow TCP/3001 from alb-sg (Direct ALB access)
- Allow TCP/3001 from frontend-sg (Frontend calls)

# Outbound
- Allow TCP/5432 to db-sg (Database)
- Allow TCP/443 to 0.0.0.0/0 (External APIs)
```

#### Database Security Group
```hcl
# Inbound
- Allow TCP/5432 from backend-sg only

# Outbound
- Deny all (no outbound required)
```

### Network ACLs (Stateless Firewall)

**Default Configuration:** AWS default (allow all)

**Future Enhancement:** Custom NACLs for additional security layer

### VPC Flow Logs

**Configuration:**
- Capture: ALL traffic (accepted and rejected)
- Destination: CloudWatch Logs
- Retention: 7 days (dev), 30 days (prod)
- Analysis: CloudWatch Insights

**Use Cases:**
- Detect port scanning attempts
- Identify unauthorized access attempts
- Troubleshoot connectivity issues
- Security incident investigation

## Identity and Access Management (IAM)

### IAM Roles and Policies

#### ECS Task Execution Role

**Purpose:** Allow ECS to pull images and write logs

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuthorizationToken",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "ECRImageAccess",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": [
        "arn:aws:ecr:us-east-1:123456789012:repository/davidshaevel-ecr-frontend",
        "arn:aws:ecr:us-east-1:123456789012:repository/davidshaevel-ecr-backend"
      ]
    },
    {
      "Sid": "CloudWatchLogsAccess",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:us-east-1:123456789012:log-group:/aws/ecs/dev-davidshaevel-*:*"
    }
  ]
}
```

**Note:** 
- `ecr:GetAuthorizationToken` requires `Resource: "*"` per AWS API requirements
- ECR image pull actions are scoped to specific repositories
- CloudWatch Logs actions are scoped to ECS log groups only

#### ECS Task Role - Frontend

**Purpose:** Frontend container permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::static-assets-bucket/*"
    }
  ]
}
```

#### ECS Task Role - Backend

**Purpose:** Backend container permissions

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:dev/davidshaevel/database/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::user-uploads-bucket/*"
    }
  ]
}
```

**Note:** ECS Fargate is serverless and does not require an EC2 instance role. Only task execution and task roles are needed.

### IAM Best Practices

1. **No Root Account Usage:** Root account MFA-enabled, not used for daily operations
2. **MFA Required:** All IAM users must have MFA enabled
3. **Temporary Credentials:** Use STS assumed roles instead of long-lived credentials
4. **Service-Specific Roles:** Each service has its own dedicated role
5. **Regular Rotation:** Rotate credentials every 90 days
6. **Audit Access:** CloudTrail logs all IAM activities

## Data Protection

### Encryption at Rest

#### RDS Database Encryption

**Configuration:**
- Encryption: Enabled (AWS KMS)
- KMS Key: Customer-managed key
- Algorithm: AES-256
- Automated backups: Encrypted
- Read replicas: Encrypted

**KMS Key Policy:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:root"
      },
      "Action": "kms:*",
      "Resource": "*"
    },
    {
      "Sid": "Allow RDS to use the key",
      "Effect": "Allow",
      "Principal": {
        "Service": "rds.amazonaws.com"
      },
      "Action": [
        "kms:Decrypt",
        "kms:CreateGrant"
      ],
      "Resource": "*"
    }
  ]
}
```

#### S3 Bucket Encryption

**Static Assets Bucket:**
- Default encryption: Enabled
- Algorithm: AES-256 (SSE-S3)
- Bucket policies: Enforce encryption

**Terraform State Bucket:**
- Default encryption: Enabled
- Algorithm: AES-256 (SSE-S3)
- Versioning: Enabled
- MFA Delete: Enabled (production)

**S3 Bucket Policy (Enforce Encryption):**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "DenyUnencryptedObjectUploads",
      "Effect": "Deny",
      "Principal": "*",
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::bucket-name/*",
      "Condition": {
        "StringNotEquals": {
          "s3:x-amz-server-side-encryption": "AES256"
        }
      }
    }
  ]
}
```

#### EBS Volume Encryption

**ECS Instance Volumes:**
- Encryption: Enabled
- KMS Key: Default AWS-managed key
- All volumes encrypted by default

### Encryption in Transit

#### HTTPS/TLS

**Requirements:**
- All external traffic: HTTPS only (TLS 1.2+)
- HTTP: Redirect to HTTPS at ALB
- Certificate: AWS ACM (free, auto-renewal)
- Cipher suites: Strong ciphers only

**ALB HTTPS Listener Configuration:**
```hcl
ssl_policy = "ELBSecurityPolicy-TLS-1-2-2017-01"
certificate_arn = aws_acm_certificate.main.arn
```

**Supported TLS Versions:**
- TLS 1.2 ✅
- TLS 1.3 ✅
- TLS 1.1 ❌
- TLS 1.0 ❌

#### Database Connections

**RDS Connection:**
- Require SSL: Enabled
- Certificate verification: Required in production
- Connection string: `sslmode=require`

**Backend Connection String:**
```
postgresql://username:password@host:5432/database?sslmode=require
```

#### Internal Service Communication

**Container-to-Container:**
- Current: HTTP (within VPC)
- Future Enhancement: mTLS with service mesh (Istio/App Mesh)

## Secrets Management

### AWS Secrets Manager

**Use Cases:**
- Database credentials
- API keys and tokens
- JWT signing keys
- Third-party service credentials

**Secret Naming Convention:**
```
{environment}/davidshaevel/{component}/{secret-name}

Examples:
- dev/davidshaevel/database/master-password
- prod/davidshaevel/api/jwt-secret
- dev/davidshaevel/github/deploy-token
```

**Rotation:**
- Database passwords: Automatic rotation every 30 days
- API keys: Manual rotation every 90 days
- Credentials stored encrypted with KMS

**Access Control:**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::123456789012:role/ecs-task-backend"
      },
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:us-east-1:123456789012:secret:dev/davidshaevel/database/*"
    }
  ]
}
```

### Environment Variables

**Sensitive Data:**
- ❌ Never store in Dockerfile
- ❌ Never commit to Git
- ✅ Store in Secrets Manager
- ✅ Inject at runtime via ECS task definition

**Non-Sensitive Configuration:**
- ✅ Can use environment variables
- ✅ Can use SSM Parameter Store
- ✅ Document in `.env.example`

## Application Security

### Authentication & Authorization

**Future Implementation:**
- JWT-based authentication
- Role-based access control (RBAC)
- OAuth 2.0 for third-party integrations
- Session management with Redis

### Input Validation

**Backend (Nest.js):**
- Use `class-validator` for DTO validation
- Sanitize all user inputs
- Parameterized database queries (prevent SQL injection)
- Rate limiting on API endpoints

### Security Headers

**Frontend (Next.js):**
```javascript
// next.config.js
module.exports = {
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'X-XSS-Protection',
            value: '1; mode=block',
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=31536000; includeSubDomains',
          },
          {
            key: 'Content-Security-Policy',
            value: "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline';",
          },
        ],
      },
    ];
  },
};
```

### Dependency Management

**Security Scanning:**
- GitHub Dependabot: Automated vulnerability alerts
- npm audit: Regular security audits
- Container scanning: AWS ECR image scanning

**Update Policy:**
- Critical vulnerabilities: Patch immediately
- High vulnerabilities: Patch within 7 days
- Medium/Low: Patch in next release cycle

## Monitoring and Logging

### CloudTrail

**Configuration:**
- Multi-region trail: Enabled
- Log file validation: Enabled
- S3 bucket: Encrypted and versioned
- CloudWatch Logs: Enabled for real-time monitoring

**Monitored Events:**
- All API calls
- IAM changes
- Security group modifications
- Network ACL changes
- Resource creation/deletion

### CloudWatch Logs

**Log Groups:**
```
/aws/vpc/dev-davidshaevel-flow-logs
/aws/ecs/dev-davidshaevel-frontend
/aws/ecs/dev-davidshaevel-backend
/aws/rds/dev-davidshaevel-postgres
/aws/lambda/dev-davidshaevel-*
```

**Retention:**
- Development: 7 days
- Production: 30 days
- Audit logs: 90 days

### Security Alarms

**CloudWatch Alarms:**

1. **Unauthorized API Calls**
   - Metric: UnauthorizedAPICallsMetric
   - Threshold: > 5 in 5 minutes
   - Action: SNS notification

2. **IAM Policy Changes**
   - Metric: IAMPolicyChanges
   - Threshold: > 0
   - Action: SNS notification

3. **Security Group Changes**
   - Metric: SecurityGroupChanges
   - Threshold: > 0
   - Action: SNS notification

4. **Failed Login Attempts**
   - Metric: FailedLoginAttempts
   - Threshold: > 10 in 5 minutes
   - Action: SNS notification, potential IP block

## Compliance and Auditing

### Audit Logging

**What We Log:**
- All AWS API calls (CloudTrail)
- Application access logs (ALB)
- Database query logs (RDS)
- Container logs (ECS)
- VPC network traffic (Flow Logs)

### Compliance Considerations

**Current Status:** Development/Portfolio Project

**Future Production Requirements:**
- GDPR compliance (if EU users)
- SOC 2 Type II (if enterprise customers)
- HIPAA (if healthcare data) - N/A
- PCI DSS (if payment processing)

### Regular Security Reviews

**Schedule:**
- Weekly: Review CloudWatch security alarms
- Monthly: Review IAM permissions and access logs
- Quarterly: Conduct security assessment
- Annually: Third-party security audit (production)

## Incident Response

### Security Incident Procedure

1. **Detection**
   - CloudWatch alarms trigger
   - Manual discovery
   - External notification

2. **Containment**
   - Isolate affected resources
   - Revoke compromised credentials
   - Block malicious IPs

3. **Investigation**
   - Review CloudTrail logs
   - Analyze VPC Flow Logs
   - Check application logs
   - Determine scope and impact

4. **Remediation**
   - Patch vulnerabilities
   - Rotate credentials
   - Update security groups
   - Apply configuration changes

5. **Recovery**
   - Restore from backups if needed
   - Verify system integrity
   - Resume normal operations

6. **Post-Incident Review**
   - Document incident timeline
   - Identify root cause
   - Implement preventive measures
   - Update runbooks

### Emergency Contacts

- AWS Support: Premium support (production)
- On-call engineer: PagerDuty integration
- Security team: security@davidshaevel.com

## Security Checklist

### Pre-Deployment Security Checklist

- [ ] All security groups follow least privilege principle
- [ ] Database encryption enabled (at rest and in transit)
- [ ] S3 buckets have encryption and versioning enabled
- [ ] IAM roles use minimal required permissions
- [ ] Secrets stored in AWS Secrets Manager (not env vars)
- [ ] HTTPS enforced on all external endpoints
- [ ] CloudTrail enabled and logging to secure S3 bucket
- [ ] VPC Flow Logs enabled for all VPCs
- [ ] CloudWatch alarms configured for security events
- [ ] Multi-factor authentication enabled for all users
- [ ] Database backups configured and tested
- [ ] Dependency vulnerabilities scanned and resolved
- [ ] Container images scanned for vulnerabilities
- [ ] Security headers configured in application
- [ ] Rate limiting enabled on API endpoints
- [ ] Input validation implemented
- [ ] SQL injection prevention (parameterized queries)
- [ ] XSS protection enabled
- [ ] CSRF protection enabled

### Regular Security Maintenance

- [ ] Review and rotate credentials every 90 days
- [ ] Update dependencies monthly
- [ ] Review IAM permissions quarterly
- [ ] Conduct security assessments quarterly
- [ ] Test backup restoration monthly
- [ ] Review CloudTrail logs weekly
- [ ] Update SSL/TLS certificates before expiration
- [ ] Review security group rules monthly

## Security Tools and Resources

**AWS Security Services:**
- AWS Security Hub: Centralized security findings
- AWS GuardDuty: Threat detection
- AWS Inspector: Vulnerability assessment
- AWS Config: Resource compliance monitoring
- AWS WAF: Web application firewall (future)

**Third-Party Tools:**
- Dependabot: Dependency vulnerability scanning
- Snyk: Container and code security scanning
- Trivy: Container vulnerability scanner

## Cost of Security

**Monthly Security Costs (Estimate):**

| Service | Monthly Cost |
|---------|--------------|
| Secrets Manager | ~$1 (2 secrets) |
| KMS Keys | ~$2 (2 keys) |
| CloudTrail | ~$2 (included in free tier) |
| VPC Flow Logs | ~$5 (100GB/month) |
| ACM Certificate | $0 (free) |
| **Total** | **~$10/month** |

**Note:** Security is a minimal additional cost but provides significant value in risk reduction.

---

**Last Updated:** October 23, 2025  
**Next Review:** After initial deployment  
**Security Contact:** david@davidshaevel.com


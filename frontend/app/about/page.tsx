export default function About() {
  return (
    <div className="min-h-screen bg-white dark:bg-zinc-950">
      <div className="mx-auto max-w-4xl px-4 py-16 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl font-bold tracking-tight text-zinc-900 dark:text-zinc-50 sm:text-5xl">
            About Me
          </h1>
          <p className="mt-6 text-xl text-zinc-600 dark:text-zinc-400">
            Platform Engineer with a passion for building scalable, reliable infrastructure
          </p>
        </div>

        {/* Bio Section */}
        <div className="mt-16 space-y-8 text-lg text-zinc-600 dark:text-zinc-400">
          <p>
            I'm David Shaevel, a Platform Engineer based in Austin, Texas, specializing in AWS cloud 
            architecture, infrastructure as code, and DevOps best practices. With extensive experience 
            in building production-grade systems, I focus on creating reliable, scalable, and secure 
            infrastructure that enables teams to ship faster.
          </p>
          <p>
            My approach to platform engineering emphasizes automation, observability, and security from 
            the ground up. I believe in infrastructure as code, comprehensive monitoring, and building 
            systems that are both maintainable and resilient.
          </p>
        </div>

        {/* Technical Expertise */}
        <div className="mt-16">
          <h2 className="text-2xl font-bold text-zinc-900 dark:text-zinc-50">
            Technical Expertise
          </h2>
          <div className="mt-8 grid gap-8 sm:grid-cols-2">
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Cloud & Infrastructure
              </h3>
              <ul className="mt-4 space-y-2 text-zinc-600 dark:text-zinc-400">
                <li>• AWS (VPC, ECS, RDS, ALB, CloudFront, Route53)</li>
                <li>• Terraform & Infrastructure as Code</li>
                <li>• Multi-AZ High Availability</li>
                <li>• Network Architecture & Security</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                DevOps & Automation
              </h3>
              <ul className="mt-4 space-y-2 text-zinc-600 dark:text-zinc-400">
                <li>• GitHub Actions CI/CD</li>
                <li>• Docker & Containerization</li>
                <li>• ECS Fargate Deployments</li>
                <li>• Automated Testing & Deployment</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Observability
              </h3>
              <ul className="mt-4 space-y-2 text-zinc-600 dark:text-zinc-400">
                <li>• CloudWatch Metrics & Alarms</li>
                <li>• Prometheus & Grafana</li>
                <li>• Application Performance Monitoring</li>
                <li>• Log Aggregation & Analysis</li>
              </ul>
            </div>
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Development
              </h3>
              <ul className="mt-4 space-y-2 text-zinc-600 dark:text-zinc-400">
                <li>• TypeScript & Node.js</li>
                <li>• Next.js & React</li>
                <li>• Nest.js API Development</li>
                <li>• PostgreSQL & Database Design</li>
              </ul>
            </div>
          </div>
        </div>

        {/* Approach */}
        <div className="mt-16">
          <h2 className="text-2xl font-bold text-zinc-900 dark:text-zinc-50">
            My Approach
          </h2>
          <div className="mt-8 space-y-6 text-zinc-600 dark:text-zinc-400">
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Infrastructure as Code First
              </h3>
              <p className="mt-2">
                Every piece of infrastructure should be codified, version-controlled, and reproducible. 
                This ensures consistency across environments and enables confident deployments.
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Security by Default
              </h3>
              <p className="mt-2">
                Security isn't an afterthought—it's built into every layer. From least-privilege IAM 
                to encrypted secrets and secure network architecture, security is fundamental.
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Comprehensive Observability
              </h3>
              <p className="mt-2">
                You can't improve what you can't measure. I implement detailed monitoring, alerting, 
                and logging from day one, providing visibility into system health and performance.
              </p>
            </div>
            <div>
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Automation & Efficiency
              </h3>
              <p className="mt-2">
                Manual processes are error-prone and don't scale. I automate repetitive tasks, 
                enabling teams to focus on building features rather than managing infrastructure.
              </p>
            </div>
          </div>
        </div>

        {/* Location */}
        <div className="mt-16 rounded-2xl border border-zinc-200 bg-zinc-50 p-8 dark:border-zinc-800 dark:bg-zinc-900">
          <div className="flex items-center gap-3">
            <svg
              className="h-6 w-6 text-zinc-600 dark:text-zinc-400"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
              />
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                strokeWidth={2}
                d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
              />
            </svg>
            <div>
              <p className="font-semibold text-zinc-900 dark:text-zinc-50">Based in Austin, Texas</p>
              <p className="mt-1 text-sm text-zinc-600 dark:text-zinc-400">
                Available for remote work and on-site consultations
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}


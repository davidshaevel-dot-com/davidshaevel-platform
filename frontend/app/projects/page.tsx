import Link from 'next/link';

export default function Projects() {
  return (
    <div className="min-h-screen bg-white dark:bg-zinc-950">
      <div className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl font-bold tracking-tight text-zinc-900 dark:text-zinc-50 sm:text-5xl">
            Projects
          </h1>
          <p className="mt-6 text-xl text-zinc-600 dark:text-zinc-400">
            Production-grade platform engineering demonstrations
          </p>
        </div>

        {/* Main Project - This Platform */}
        <div className="mt-16">
          <div className="overflow-hidden rounded-3xl border border-zinc-200 bg-gradient-to-br from-blue-50 to-cyan-50 dark:border-zinc-800 dark:from-zinc-900 dark:to-zinc-800">
            <div className="p-8 sm:p-12">
              <div className="flex items-center gap-3">
                <svg
                  className="h-8 w-8 text-blue-600 dark:text-blue-400"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    strokeWidth={2}
                    d="M3 15a4 4 0 004 4h9a5 5 0 10-.1-9.999 5.002 5.002 0 10-9.78 2.096A4.001 4.001 0 003 15z"
                  />
                </svg>
                <span className="rounded-full bg-blue-100 px-3 py-1 text-sm font-medium text-blue-800 dark:bg-blue-900 dark:text-blue-200">
                  Featured Project
                </span>
              </div>
              <h2 className="mt-6 text-3xl font-bold text-zinc-900 dark:text-zinc-50">
                DavidShaevel.com Platform
              </h2>
              <p className="mt-4 text-lg text-zinc-700 dark:text-zinc-300">
                A full-stack platform engineering portfolio demonstrating production-ready AWS infrastructure,
                infrastructure as code, and modern DevOps practices.
              </p>

              {/* Architecture Overview */}
              <div className="mt-8 grid gap-6 sm:grid-cols-2 lg:grid-cols-3">
                <div className="rounded-lg bg-white p-4 dark:bg-zinc-950">
                  <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">Cloud Infrastructure</h3>
                  <ul className="mt-2 space-y-1 text-sm text-zinc-600 dark:text-zinc-400">
                    <li>• AWS VPC with multi-AZ</li>
                    <li>• ECS Fargate containerization</li>
                    <li>• RDS PostgreSQL database</li>
                    <li>• Application Load Balancer</li>
                    <li>• CloudFront CDN</li>
                  </ul>
                </div>
                <div className="rounded-lg bg-white p-4 dark:bg-zinc-950">
                  <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">Infrastructure as Code</h3>
                  <ul className="mt-2 space-y-1 text-sm text-zinc-600 dark:text-zinc-400">
                    <li>• Terraform modules</li>
                    <li>• Remote state (S3 + DynamoDB)</li>
                    <li>• Modular architecture</li>
                    <li>• Environment separation</li>
                    <li>• Reusable components</li>
                  </ul>
                </div>
                <div className="rounded-lg bg-white p-4 dark:bg-zinc-950">
                  <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">Security & Best Practices</h3>
                  <ul className="mt-2 space-y-1 text-sm text-zinc-600 dark:text-zinc-400">
                    <li>• Least-privilege IAM</li>
                    <li>• AWS Secrets Manager</li>
                    <li>• Security groups</li>
                    <li>• SSL/TLS with ACM</li>
                    <li>• Encrypted data at rest</li>
                  </ul>
                </div>
              </div>

              {/* Tech Stack */}
              <div className="mt-8">
                <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">Technology Stack</h3>
                <div className="mt-4 flex flex-wrap gap-2">
                  {[
                    'AWS',
                    'Terraform',
                    'Next.js',
                    'Nest.js',
                    'TypeScript',
                    'PostgreSQL',
                    'Docker',
                    'GitHub Actions',
                    'CloudWatch',
                    'Prometheus',
                    'Grafana',
                  ].map((tech) => (
                    <span
                      key={tech}
                      className="rounded-full bg-zinc-900 px-3 py-1 text-sm font-medium text-white dark:bg-white dark:text-zinc-900"
                    >
                      {tech}
                    </span>
                  ))}
                </div>
              </div>

              {/* Key Features */}
              <div className="mt-8">
                <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">Key Features</h3>
                <ul className="mt-4 grid gap-3 sm:grid-cols-2">
                  <li className="flex items-start gap-2">
                    <svg className="mt-1 h-5 w-5 flex-shrink-0 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="text-sm text-zinc-700 dark:text-zinc-300">76 AWS resources deployed</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="mt-1 h-5 w-5 flex-shrink-0 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="text-sm text-zinc-700 dark:text-zinc-300">High availability across 2 AZs</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="mt-1 h-5 w-5 flex-shrink-0 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="text-sm text-zinc-700 dark:text-zinc-300">Production-ready security architecture</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="mt-1 h-5 w-5 flex-shrink-0 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="text-sm text-zinc-700 dark:text-zinc-300">Comprehensive monitoring & alerting</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="mt-1 h-5 w-5 flex-shrink-0 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="text-sm text-zinc-700 dark:text-zinc-300">Automated CI/CD pipeline</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <svg className="mt-1 h-5 w-5 flex-shrink-0 text-green-600" fill="currentColor" viewBox="0 0 20 20">
                      <path fillRule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clipRule="evenodd" />
                    </svg>
                    <span className="text-sm text-zinc-700 dark:text-zinc-300">Custom domain with HTTPS</span>
                  </li>
                </ul>
              </div>

              {/* Links */}
              <div className="mt-8 flex flex-wrap gap-4">
                <a
                  href="https://github.com/davidshaevel-dot-com/davidshaevel-platform"
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-2 rounded-full bg-zinc-900 px-6 py-3 text-sm font-semibold text-white transition-colors hover:bg-zinc-700 dark:bg-white dark:text-zinc-900 dark:hover:bg-zinc-200"
                >
                  <svg className="h-5 w-5" fill="currentColor" viewBox="0 0 24 24">
                    <path fillRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clipRule="evenodd" />
                  </svg>
                  View on GitHub
                </a>
                <Link
                  href="/contact"
                  className="inline-flex items-center gap-2 rounded-full border border-zinc-900 px-6 py-3 text-sm font-semibold text-zinc-900 transition-colors hover:bg-zinc-100 dark:border-white dark:text-white dark:hover:bg-zinc-900"
                >
                  Discuss This Project
                  <span aria-hidden="true">→</span>
                </Link>
              </div>
            </div>
          </div>
        </div>

        {/* Additional Context */}
        <div className="mt-16 text-center">
          <p className="text-zinc-600 dark:text-zinc-400">
            More projects coming soon. This portfolio demonstrates my current approach to 
            production-ready platform engineering and infrastructure automation.
          </p>
        </div>
      </div>
    </div>
  );
}


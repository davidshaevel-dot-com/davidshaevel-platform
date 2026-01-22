'use client';

import { useState } from 'react';

export default function Contact() {
  const [formState, setFormState] = useState<'idle' | 'submitting' | 'submitted' | 'error'>('idle');
  const [errorMessage, setErrorMessage] = useState<string>('');

  const handleSubmit = async (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    setFormState('submitting');
    setErrorMessage('');

    const formData = new FormData(e.currentTarget);
    const data = {
      name: formData.get('name') as string,
      email: formData.get('email') as string,
      subject: formData.get('subject') as string,
      message: formData.get('message') as string,
    };

    try {
      const apiUrl = process.env.NEXT_PUBLIC_API_URL || '';
      const response = await fetch(`${apiUrl}/api/contact`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify(data),
      });

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}));
        throw new Error(errorData.message || 'Failed to send message');
      }

      setFormState('submitted');

      // Reset after 3 seconds
      setTimeout(() => {
        setFormState('idle');
        (e.target as HTMLFormElement).reset();
      }, 3000);
    } catch (error) {
      setFormState('error');
      setErrorMessage(error instanceof Error ? error.message : 'Failed to send message. Please try again.');

      // Reset error state after 5 seconds
      setTimeout(() => {
        setFormState('idle');
        setErrorMessage('');
      }, 5000);
    }
  };

  return (
    <div className="min-h-screen bg-white dark:bg-zinc-950">
      <div className="mx-auto max-w-7xl px-4 py-16 sm:px-6 lg:px-8">
        {/* Header */}
        <div className="text-center">
          <h1 className="text-4xl font-bold tracking-tight text-zinc-900 dark:text-zinc-50 sm:text-5xl">
            Get in Touch
          </h1>
          <p className="mt-6 text-xl text-zinc-600 dark:text-zinc-400">
            Let&apos;s discuss how platform engineering can help your team
          </p>
        </div>

        <div className="mt-16 grid gap-12 lg:grid-cols-2">
          {/* Contact Form */}
          <div>
            <form onSubmit={handleSubmit} className="space-y-6">
              <div>
                <label htmlFor="name" className="block text-sm font-medium text-zinc-900 dark:text-zinc-50">
                  Name
                </label>
                <input
                  type="text"
                  id="name"
                  name="name"
                  required
                  className="mt-2 block w-full rounded-lg border border-zinc-300 bg-white px-4 py-3 text-zinc-900 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
                  placeholder="Your name"
                  disabled={formState === 'submitting' || formState === 'submitted'}
                />
              </div>

              <div>
                <label htmlFor="email" className="block text-sm font-medium text-zinc-900 dark:text-zinc-50">
                  Email
                </label>
                <input
                  type="email"
                  id="email"
                  name="email"
                  required
                  className="mt-2 block w-full rounded-lg border border-zinc-300 bg-white px-4 py-3 text-zinc-900 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
                  placeholder="your.email@example.com"
                  disabled={formState === 'submitting' || formState === 'submitted'}
                />
              </div>

              <div>
                <label htmlFor="subject" className="block text-sm font-medium text-zinc-900 dark:text-zinc-50">
                  Subject
                </label>
                <input
                  type="text"
                  id="subject"
                  name="subject"
                  required
                  className="mt-2 block w-full rounded-lg border border-zinc-300 bg-white px-4 py-3 text-zinc-900 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
                  placeholder="What would you like to discuss?"
                  disabled={formState === 'submitting' || formState === 'submitted'}
                />
              </div>

              <div>
                <label htmlFor="message" className="block text-sm font-medium text-zinc-900 dark:text-zinc-50">
                  Message
                </label>
                <textarea
                  id="message"
                  name="message"
                  rows={6}
                  required
                  className="mt-2 block w-full rounded-lg border border-zinc-300 bg-white px-4 py-3 text-zinc-900 shadow-sm focus:border-blue-500 focus:outline-none focus:ring-2 focus:ring-blue-500 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-50"
                  placeholder="Tell me about your project or question..."
                  disabled={formState === 'submitting' || formState === 'submitted'}
                />
              </div>

              <button
                type="submit"
                disabled={formState !== 'idle' && formState !== 'error'}
                className="w-full rounded-full bg-zinc-900 px-6 py-3 text-sm font-semibold text-white shadow-sm transition-colors hover:bg-zinc-700 disabled:opacity-50 dark:bg-white dark:text-zinc-900 dark:hover:bg-zinc-200"
              >
                {formState === 'idle' && 'Send Message'}
                {formState === 'submitting' && 'Sending...'}
                {formState === 'submitted' && '✓ Message Sent!'}
                {formState === 'error' && 'Try Again'}
              </button>

              {formState === 'submitted' && (
                <p className="text-center text-sm text-green-600 dark:text-green-400">
                  Thank you! I&apos;ll get back to you soon.
                </p>
              )}

              {formState === 'error' && (
                <p className="text-center text-sm text-red-600 dark:text-red-400">
                  {errorMessage}
                </p>
              )}
            </form>
          </div>

          {/* Contact Information */}
          <div className="space-y-8">
            <div>
              <h2 className="text-2xl font-bold text-zinc-900 dark:text-zinc-50">
                Contact Information
              </h2>
              <p className="mt-4 text-zinc-600 dark:text-zinc-400">
                Feel free to reach out through any of these channels. I&apos;m always interested in
                discussing platform engineering, infrastructure challenges, and exciting opportunities.
              </p>
            </div>

            <div className="space-y-6">
              {/* Location */}
              <div className="flex items-start gap-4">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-blue-100 dark:bg-blue-900">
                  <svg className="h-6 w-6 text-blue-600 dark:text-blue-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">Location</h3>
                  <p className="mt-1 text-zinc-600 dark:text-zinc-400">
                    Austin, Texas<br />
                    Available for remote work
                  </p>
                </div>
              </div>

              {/* GitHub */}
              <div className="flex items-start gap-4">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-zinc-100 dark:bg-zinc-800">
                  <svg className="h-6 w-6 text-zinc-900 dark:text-zinc-50" fill="currentColor" viewBox="0 0 24 24">
                    <path fillRule="evenodd" d="M12 2C6.477 2 2 6.484 2 12.017c0 4.425 2.865 8.18 6.839 9.504.5.092.682-.217.682-.483 0-.237-.008-.868-.013-1.703-2.782.605-3.369-1.343-3.369-1.343-.454-1.158-1.11-1.466-1.11-1.466-.908-.62.069-.608.069-.608 1.003.07 1.531 1.032 1.531 1.032.892 1.53 2.341 1.088 2.91.832.092-.647.35-1.088.636-1.338-2.22-.253-4.555-1.113-4.555-4.951 0-1.093.39-1.988 1.029-2.688-.103-.253-.446-1.272.098-2.65 0 0 .84-.27 2.75 1.026A9.564 9.564 0 0112 6.844c.85.004 1.705.115 2.504.337 1.909-1.296 2.747-1.027 2.747-1.027.546 1.379.202 2.398.1 2.651.64.7 1.028 1.595 1.028 2.688 0 3.848-2.339 4.695-4.566 4.943.359.309.678.92.678 1.855 0 1.338-.012 2.419-.012 2.747 0 .268.18.58.688.482A10.019 10.019 0 0022 12.017C22 6.484 17.522 2 12 2z" clipRule="evenodd" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">GitHub</h3>
                  <a
                    href="https://github.com/davidshaevel-dot-com"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-1 text-blue-600 hover:underline dark:text-blue-400"
                  >
                    github.com/davidshaevel-dot-com
                  </a>
                </div>
              </div>

              {/* LinkedIn */}
              <div className="flex items-start gap-4">
                <div className="flex h-12 w-12 items-center justify-center rounded-lg bg-blue-600">
                  <svg className="h-6 w-6 text-white" fill="currentColor" viewBox="0 0 24 24">
                    <path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z" />
                  </svg>
                </div>
                <div>
                  <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">LinkedIn</h3>
                  <a
                    href="https://www.linkedin.com/in/dshaevel"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="mt-1 text-blue-600 hover:underline dark:text-blue-400"
                  >
                    linkedin.com/in/dshaevel
                  </a>
                </div>
              </div>
            </div>

            {/* Additional Info */}
            <div className="rounded-2xl border border-zinc-200 bg-zinc-50 p-6 dark:border-zinc-800 dark:bg-zinc-900">
              <h3 className="font-semibold text-zinc-900 dark:text-zinc-50">
                Interested in collaborating?
              </h3>
              <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400">
                I&apos;m always open to discussing platform engineering challenges, infrastructure
                consulting, or full-time opportunities. Whether you need help with AWS architecture,
                Terraform modules, or building scalable systems, let&apos;s talk.
              </p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}


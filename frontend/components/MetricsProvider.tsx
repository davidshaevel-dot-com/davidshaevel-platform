'use client';

import { usePathname } from 'next/navigation';
import { useEffect } from 'react';

/**
 * MetricsProvider
 *
 * Client component that tracks page views for Prometheus metrics.
 * Automatically records a page view metric whenever the route changes.
 *
 * This component should be used in the root layout to track all page navigations.
 */
export function MetricsProvider({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();

  useEffect(() => {
    // Record page view whenever the pathname changes
    if (pathname) {
      // Call server-side API route to record page view
      // Fire and forget - don't await, don't block rendering
      fetch('/api/metrics/page-view', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ page: pathname, method: 'GET' }),
      }).catch(() => {
        // Silently fail - metrics recording should not break the app
      });
    }
  }, [pathname]);

  return <>{children}</>;
}

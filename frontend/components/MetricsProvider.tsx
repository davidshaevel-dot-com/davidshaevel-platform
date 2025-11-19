'use client';

import { usePathname } from 'next/navigation';
import { useEffect } from 'react';
import { recordPageView } from '@/lib/metrics';

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
      recordPageView(pathname, 'GET');
    }
  }, [pathname]);

  return <>{children}</>;
}

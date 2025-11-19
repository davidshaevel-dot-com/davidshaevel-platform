import { recordApiCall } from '@/lib/metrics';

/**
 * API Client with Prometheus Metrics Integration
 *
 * This module provides a fetch wrapper that automatically records API call metrics
 * for Prometheus monitoring.
 *
 * Usage:
 *   import { fetchWithMetrics } from '@/lib/api-client';
 *
 *   const response = await fetchWithMetrics('/api/projects', {
 *     method: 'GET',
 *   });
 *
 * Metrics Recorded:
 *   - frontend_api_calls_total: Counter of API calls by endpoint, method, and status
 *   - frontend_api_call_duration_seconds: Histogram of API call durations
 */

/**
 * Fetch wrapper that records Prometheus metrics for all API calls
 *
 * @param url - The URL to fetch (can be relative or absolute)
 * @param options - Standard fetch options
 * @returns Promise<Response>
 */
export async function fetchWithMetrics(
  url: string,
  options?: RequestInit
): Promise<Response> {
  const startTime = Date.now();
  const method = options?.method || 'GET';

  // Extract endpoint path from URL
  let endpoint: string;
  try {
    const urlObj = new URL(url, typeof window !== 'undefined' ? window.location.origin : 'http://localhost');
    endpoint = urlObj.pathname;
  } catch {
    // If URL parsing fails, use a static placeholder to avoid cardinality issues.
    endpoint = '/invalid-url-format';
  }

  try {
    const response = await fetch(url, options);
    const duration = (Date.now() - startTime) / 1000;

    // Record successful API call metrics
    recordApiCall(endpoint, method, response.status, duration);

    return response;
  } catch (error) {
    const duration = (Date.now() - startTime) / 1000;

    // Record failed API call with status 0 (network error)
    recordApiCall(endpoint, method, 0, duration);

    throw error;
  }
}

/**
 * Type-safe wrapper for JSON API calls
 *
 * @param url - The URL to fetch
 * @param options - Fetch options
 * @returns Promise with parsed JSON response
 */
export async function fetchJSON<T = unknown>(
  url: string,
  options?: RequestInit
): Promise<T> {
  const response = await fetchWithMetrics(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      ...options?.headers,
    },
  });

  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }

  return response.json();
}

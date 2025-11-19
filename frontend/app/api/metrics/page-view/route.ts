import { NextRequest, NextResponse } from 'next/server';
import { recordPageView } from '@/lib/metrics';

/**
 * POST /api/metrics/page-view
 *
 * Server-side API route for recording page view metrics from client components.
 * This allows client components to trigger server-side metrics recording
 * without directly importing prom-client (which is server-only).
 */
export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { page, method } = body;

    if (typeof page !== 'string') {
      return NextResponse.json(
        { error: 'Invalid page parameter' },
        { status: 400 }
      );
    }

    // Record the page view metric on the server side
    recordPageView(page, method || 'GET');

    return NextResponse.json({ success: true }, { status: 200 });
  } catch (error) {
    console.error('Error recording page view metric:', error);
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    );
  }
}

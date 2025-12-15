import { ConflictException, Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomBytes } from 'node:crypto';
import { promises as fs } from 'node:fs';
import inspector from 'node:inspector';
import path from 'node:path';
import v8 from 'node:v8';

type CpuProfileState = {
  inProgress: boolean;
};

@Injectable()
export class LabService {
  private readonly retainedBuffers: Buffer[] = [];
  private cpu: CpuProfileState = { inProgress: false };

  constructor(private readonly configService: ConfigService) {}

  getStatus() {
    const totalBytes = this.retainedBuffers.reduce(
      (sum, b) => sum + b.byteLength,
      0,
    );
    return {
      labEnabled:
        this.configService.get<string>('LAB_ENABLE')?.toLowerCase() === 'true',
      nodeEnv: this.configService.get<string>('NODE_ENV') ?? 'unknown',
      appEnv: this.configService.get<string>('APP_ENV') ?? null,
      retainedBufferCount: this.retainedBuffers.length,
      retainedBytes: totalBytes,
      cpuProfileInProgress: this.cpu.inProgress,
    };
  }

  eventLoopJam(ms: number) {
    const durationMs = clampInt(ms, 1, 60_000);
    const start = Date.now();
    let x = 0;
    while (Date.now() - start < durationMs) {
      // Busy work to keep the CPU hot and block the event loop.
      x = Math.sqrt(x + 1) * 1.0000001;
    }
    return { jammedMs: durationMs, result: x };
  }

  retainMemory(megabytes: number) {
    const mb = clampInt(megabytes, 1, 1024);
    const buf = Buffer.alloc(mb * 1024 * 1024, 0x7f);
    this.retainedBuffers.push(buf);
    return this.getStatus();
  }

  clearRetainedMemory() {
    this.retainedBuffers.length = 0;
    return this.getStatus();
  }

  async writeHeapSnapshot(): Promise<{ filePath: string }> {
    const filePath = path.join(
      '/tmp',
      `heap-${new Date().toISOString().replaceAll(':', '-')}-${randomBytes(4).toString('hex')}.heapsnapshot`,
    );
    // v8.writeHeapSnapshot returns the filename it wrote.
    const written = v8.writeHeapSnapshot(filePath);
    return { filePath: written };
  }

  async captureCpuProfile(seconds: number): Promise<{ filePath: string; durationSeconds: number }> {
    if (this.cpu.inProgress) {
      throw new ConflictException('CPU profile already in progress');
    }

    const durationSeconds = clampInt(seconds, 1, 120);
    this.cpu.inProgress = true;

    const session = new inspector.Session();
    session.connect();

    try {
      await post(session, 'Profiler.enable');
      await post(session, 'Profiler.start');

      await sleep(durationSeconds * 1000);

      const { profile } = await post<{ profile: unknown }>(session, 'Profiler.stop');
      const filePath = path.join('/tmp', `cpu-${new Date().toISOString().replaceAll(':', '-')}-${randomBytes(4).toString('hex')}.cpuprofile`);
      await fs.writeFile(filePath, JSON.stringify(profile));

      return { filePath, durationSeconds };
    } finally {
      try {
        session.disconnect();
      } catch {
        // ignore
      }
      this.cpu.inProgress = false;
    }
  }
}

function clampInt(value: number, min: number, max: number): number {
  if (!Number.isFinite(value)) return min;
  const n = Math.trunc(value);
  if (n < min) return min;
  if (n > max) return max;
  return n;
}

function sleep(ms: number) {
  return new Promise<void>((resolve) => setTimeout(resolve, ms));
}

function post<T = unknown>(session: inspector.Session, method: string, params?: object): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    session.post(method, params ?? {}, (err: Error | null, result: T) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
}






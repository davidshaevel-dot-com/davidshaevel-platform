import { Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { LabGuard } from './lab.guard';
import { LabService } from './lab.service';

@Controller('lab')
@UseGuards(LabGuard)
export class LabController {
  constructor(private readonly labService: LabService) {}

  @Get('status')
  status() {
    return this.labService.getStatus();
  }

  @Post('event-loop-jam')
  eventLoopJam(@Query('ms') ms?: string) {
    const n = ms ? Number(ms) : 2000;
    return this.labService.eventLoopJam(n);
  }

  @Post('memory-leak')
  memoryLeak(@Query('mb') mb?: string) {
    const n = mb ? Number(mb) : 64;
    return this.labService.retainMemory(n);
  }

  @Post('memory-clear')
  memoryClear() {
    return this.labService.clearRetainedMemory();
  }

  @Post('heap-snapshot')
  heapSnapshot() {
    return this.labService.writeHeapSnapshot();
  }

  @Post('cpu-profile')
  cpuProfile(@Query('seconds') seconds?: string) {
    const n = seconds ? Number(seconds) : 30;
    return this.labService.captureCpuProfile(n);
  }
}






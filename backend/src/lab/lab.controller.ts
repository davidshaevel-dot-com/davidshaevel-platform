import {
  Controller,
  DefaultValuePipe,
  Get,
  ParseIntPipe,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
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
  eventLoopJam(
    @Query('ms', new DefaultValuePipe(2000), ParseIntPipe) ms: number,
  ) {
    return this.labService.eventLoopJam(ms);
  }

  @Post('memory-leak')
  memoryLeak(
    @Query('mb', new DefaultValuePipe(64), ParseIntPipe) mb: number,
  ) {
    return this.labService.retainMemory(mb);
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
  cpuProfile(
    @Query('seconds', new DefaultValuePipe(30), ParseIntPipe) seconds: number,
  ) {
    return this.labService.captureCpuProfile(seconds);
  }
}






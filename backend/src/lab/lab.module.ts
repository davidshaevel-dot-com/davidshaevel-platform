import { Module } from '@nestjs/common';
import { LabController } from './lab.controller';
import { LabGuard } from './lab.guard';
import { LabService } from './lab.service';

@Module({
  controllers: [LabController],
  providers: [LabService, LabGuard],
})
export class LabModule {}






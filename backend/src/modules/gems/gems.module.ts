import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { GemsController } from './gems.controller';
import { GemsService } from './gems.service';

@Module({
  imports: [AuthModule],
  providers: [GemsService],
  controllers: [GemsController],
  exports: [GemsService],
})
export class GemsModule {}

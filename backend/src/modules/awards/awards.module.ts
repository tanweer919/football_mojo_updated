import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { GemsModule } from '../gems/gems.module';
import { AwardsController } from './awards.controller';
import { AwardsService } from './awards.service';

@Module({
  imports: [AuthModule, GemsModule],
  providers: [AwardsService],
  controllers: [AwardsController],
  exports: [AwardsService],
})
export class AwardsModule {}

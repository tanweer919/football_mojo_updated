import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import {
  ArrayMinSize,
  IsArray,
  IsBoolean,
  IsInt,
  IsOptional,
  IsString,
  Min,
  MinLength,
} from 'class-validator';
import { FirebaseAuthGuard } from '../auth/firebase-auth.guard';
import { AdminRoleGuard } from './admin-role.guard';
import { AdminBundlesService } from './bundles.service';

class BundleBody {
  @IsString() @MinLength(1) name!: string;
  @IsOptional() @IsString() description?: string;
  @IsInt() @Min(1) gemPrice!: number;
  @IsOptional() @IsString() artUrl?: string;
  @IsOptional() @IsBoolean() active?: boolean;
  @IsOptional() @IsInt() sortOrder?: number;
  @IsArray() @ArrayMinSize(1) @IsString({ each: true }) templateIds!: string[];
}

@Controller({ path: 'admin/bundles', version: '1' })
@UseGuards(FirebaseAuthGuard, AdminRoleGuard)
export class AdminBundlesController {
  constructor(private readonly bundles: AdminBundlesService) {}

  @Get()
  list() {
    return this.bundles.list();
  }

  @Post()
  create(@Body() b: BundleBody) {
    return this.bundles.create(this.normalise(b));
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() b: BundleBody) {
    return this.bundles.update(id, this.normalise(b));
  }

  @Delete(':id')
  remove(@Param('id') id: string) {
    return this.bundles.remove(id);
  }

  private normalise(b: BundleBody) {
    return {
      name: b.name,
      description: b.description ?? null,
      gemPrice: b.gemPrice,
      artUrl: b.artUrl ?? null,
      active: b.active ?? true,
      sortOrder: b.sortOrder ?? 0,
      templateIds: b.templateIds,
    };
  }
}

import { IsString, IsOptional, IsArray, IsBoolean, IsNumber, IsUrl, MaxLength } from 'class-validator';

export class CreateProjectDto {
  @IsString()
  @MaxLength(200)
  title: string;

  @IsString()
  description: string;

  @IsOptional()
  @IsUrl()
  @MaxLength(500)
  imageUrl?: string;

  @IsOptional()
  @IsUrl()
  @MaxLength(500)
  projectUrl?: string;

  @IsOptional()
  @IsUrl()
  @MaxLength(500)
  githubUrl?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  technologies?: string[];

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;

  @IsOptional()
  @IsNumber()
  sortOrder?: number;
}


import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('projects')
export class Project {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  title: string;

  @Column('text')
  description: string;

  @Column({ length: 500, nullable: true })
  imageUrl: string;

  @Column({ length: 500, nullable: true })
  projectUrl: string;

  @Column({ length: 500, nullable: true })
  githubUrl: string;

  @Column({ type: 'text', array: true, nullable: true })
  technologies: string[];

  @Column({ default: true })
  isActive: boolean;

  @Column({ default: 0 })
  sortOrder: number;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}


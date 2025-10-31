#!/usr/bin/env node
/**
 * Database Migration Runner
 *
 * This script connects to PostgreSQL and runs SQL migration files in order.
 * It can be executed from within the ECS container to apply schema changes.
 *
 * Usage:
 *   node database/run-migrations.js
 *
 * Environment Variables Required:
 *   DB_HOST, DB_PORT, DB_NAME, DB_USERNAME, DB_PASSWORD
 */

const fs = require('fs');
const path = require('path');
const { Client } = require('pg');

// Database connection configuration from environment variables
const config = {
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT) || 5432,
  database: process.env.DB_NAME || 'davidshaevel',
  user: process.env.DB_USERNAME || 'dbadmin',
  password: process.env.DB_PASSWORD,
  ssl: process.env.NODE_ENV === 'production' ? {
    rejectUnauthorized: false // Required for AWS RDS
  } : false,
};

const migrationsDir = path.join(__dirname, 'migrations');

async function runMigrations() {
  const client = new Client(config);

  try {
    console.log('🔌 Connecting to database...');
    console.log(`   Host: ${config.host}`);
    console.log(`   Database: ${config.database}`);
    console.log(`   User: ${config.user}`);

    await client.connect();
    console.log('✅ Connected to database successfully\n');

    // Get all migration files
    const files = fs.readdirSync(migrationsDir)
      .filter(file => file.endsWith('.sql'))
      .sort();

    if (files.length === 0) {
      console.log('⚠️  No migration files found in', migrationsDir);
      return;
    }

    console.log(`📋 Found ${files.length} migration file(s):\n`);

    // Run each migration
    for (const file of files) {
      const filePath = path.join(migrationsDir, file);
      const sql = fs.readFileSync(filePath, 'utf8');

      console.log(`🔄 Running migration: ${file}`);

      try {
        await client.query(sql);
        console.log(`✅ Successfully applied: ${file}\n`);
      } catch (error) {
        console.error(`❌ Error applying ${file}:`);
        console.error(`   ${error.message}\n`);

        // Continue with other migrations even if one fails
        // This allows idempotent migrations (IF NOT EXISTS) to succeed
        if (!error.message.includes('already exists')) {
          throw error;
        }
      }
    }

    // Verify schema
    console.log('🔍 Verifying schema...');
    const result = await client.query(`
      SELECT table_name, column_name, data_type
      FROM information_schema.columns
      WHERE table_name = 'projects'
      ORDER BY ordinal_position
    `);

    if (result.rows.length > 0) {
      console.log('✅ Projects table schema:');
      console.table(result.rows);
    } else {
      console.log('⚠️  Projects table not found');
    }

    // Check for data
    const countResult = await client.query('SELECT COUNT(*) as count FROM projects');
    console.log(`\n📊 Projects table has ${countResult.rows[0].count} row(s)`);

  } catch (error) {
    console.error('\n❌ Migration failed:');
    console.error(error);
    process.exit(1);
  } finally {
    await client.end();
    console.log('\n🔌 Database connection closed');
  }
}

// Run migrations
console.log('🚀 Database Migration Runner\n');
console.log('=' .repeat(60));
console.log('\n');

runMigrations()
  .then(() => {
    console.log('\n' + '='.repeat(60));
    console.log('🎉 All migrations completed successfully!');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n' + '='.repeat(60));
    console.error('💥 Migration runner failed:', error.message);
    process.exit(1);
  });

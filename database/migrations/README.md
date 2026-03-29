# Database Migration Scripts

This directory contains SQL migration scripts for the Wata Board database schema.

## Migration Files

### 001_initial_schema.sql
- **Purpose**: Creates the initial database schema
- **Tables Created**:
  - `users` - User accounts and authentication
  - `meters` - Utility meter information
  - `payments` - Payment transaction records
  - `payment_cache` - Cached payment totals for performance
  - `rate_limits` - API rate limiting data
  - `audit_logs` - System audit trail
  - `system_config` - Configuration parameters
- **Features**:
  - UUID primary keys
  - JSONB metadata columns
  - Comprehensive indexes
  - Triggers for timestamp updates
  - Views for analytics
  - Stored procedures for common operations

### 002_add_indexes_and_constraints.sql
- **Purpose**: Enhances performance and data integrity
- **Features**:
  - Additional composite indexes
  - Partial indexes for common queries
  - GIN indexes for JSONB columns
  - Enhanced constraints
  - Materialized views for statistics
  - Analytics functions
  - Data cleanup procedures

### 003_blockchain_integration.sql
- **Purpose**: Adds blockchain-specific functionality
- **Tables Created**:
  - `blockchain_transactions` - Detailed blockchain transaction tracking
  - `blockchain_sync_status` - Synchronization status monitoring
  - `smart_contract_events` - Event logging
  - `blockchain_analytics` - Performance metrics
- **Features**:
  - Transaction status tracking
  - Event processing system
  - Analytics generation
  - Sync status management

## Migration Order

Migrations must be executed in the following order:
1. `001_initial_schema.sql`
2. `002_add_indexes_and_constraints.sql`
3. `003_blockchain_integration.sql`

## How to Run Migrations

### Using PostgreSQL CLI
```bash
# Connect to your database
psql -h localhost -U username -d wata_board

# Run migrations in order
\i 001_initial_schema.sql
\i 002_add_indexes_and_constraints.sql
\i 003_blockchain_integration.sql
```

### Using a Migration Tool

If you're using a migration tool like Flyway or Liquibase, you can configure it to run these scripts in order.

#### Flyway Configuration
```sql
-- Create flyway schema history table (if not exists)
CREATE TABLE IF NOT EXISTS flyway_schema_history (
    installed_rank INTEGER NOT NULL,
    version STRING,
    description STRING,
    type STRING NOT NULL,
    script STRING NOT NULL,
    checksum INTEGER,
    installed_by STRING NOT NULL,
    installed_on TIMESTAMP NOT NULL,
    execution_time INTEGER NOT NULL,
    success BOOLEAN NOT NULL
);
```

## Environment Setup

### Development Environment
```sql
-- Create database
CREATE DATABASE wata_board_dev;

-- Create user
CREATE USER wata_board_dev WITH PASSWORD 'dev_password';
GRANT ALL PRIVILEGES ON DATABASE wata_board_dev TO wata_board_dev;

-- Connect to database
\c wata_board_dev;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

### Production Environment
```sql
-- Create database
CREATE DATABASE wata_board_prod;

-- Create application user
CREATE USER wata_board_app WITH PASSWORD 'secure_password';
GRANT CONNECT ON DATABASE wata_board_prod TO wata_board_app;

-- Create read-only user
CREATE USER wata_board_readonly WITH PASSWORD 'readonly_password';
GRANT CONNECT ON DATABASE wata_board_prod TO wata_board_readonly;

-- Connect to database
\c wata_board_prod;

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gin";
```

## Post-Migration Setup

After running the migrations, you need to:

1. **Grant Permissions**:
```sql
-- For application user
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO wata_board_app;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO wata_board_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO wata_board_app;

-- For read-only user
GRANT SELECT ON ALL TABLES IN SCHEMA public TO wata_board_readonly;
GRANT SELECT ON ALL VIEWS IN SCHEMA public TO wata_board_readonly;
```

2. **Initialize System Configuration**:
```sql
-- The migrations automatically insert default configuration
-- Verify with:
SELECT * FROM system_config WHERE key LIKE 'migration_%';
```

3. **Set Up Blockchain Sync Status**:
```sql
-- Initialize sync status for testnet
INSERT INTO blockchain_sync_status (network, contract_id, sync_status)
VALUES ('testnet', 'CDRRJ7IPYDL36YSK5ZQLBG3LICULETIBXX327AGJQNTWXNKY2UMDO4DA', 'pending');
```

## Rollback Procedures

### Partial Rollback
If you need to rollback a specific migration:

1. **Identify the migration**:
```sql
SELECT * FROM system_config WHERE key LIKE 'migration_%' ORDER BY key;
```

2. **Rollback changes manually** (each migration file contains comments for rollback)

### Full Database Reset
For development environments, you can reset the entire database:
```sql
DROP DATABASE IF EXISTS wata_board_dev;
CREATE DATABASE wata_board_dev;
-- Then re-run all migrations
```

## Performance Considerations

### Index Creation
Some indexes are created with `CONCURRENTLY` to avoid locking:
```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS index_name ON table_name(columns);
```

### Materialized Views
Materialized views need to be refreshed periodically:
```sql
-- Refresh payment statistics
SELECT refresh_payment_statistics();

-- Or schedule with cron job
-- 0 */6 * * * psql -d wata_board_prod -c "SELECT refresh_payment_statistics();"
```

### Partitioning
For high-volume environments, consider table partitioning:
```sql
-- Enable partitioning (uncomment in migration 002)
-- This creates monthly partitions for the payments table
```

## Monitoring and Maintenance

### Daily Tasks
```sql
-- Clean up old audit logs (90-day retention)
SELECT cleanup_old_audit_logs(90);

-- Clean up expired rate limits
SELECT cleanup_expired_rate_limits();

-- Update table statistics
SELECT update_table_statistics();
```

### Weekly Tasks
```sql
-- Generate blockchain analytics
SELECT generate_blockchain_analytics('testnet', CURRENT_DATE - INTERVAL '7 days');

-- Process unprocessed events
SELECT process_smart_contract_events();
```

### Monthly Tasks
```sql
-- Refresh materialized views
REFRESH MATERIALIZED VIEW CONCURRENTLY payment_statistics;

-- Analyze query performance
SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;
```

## Troubleshooting

### Common Issues

1. **UUID Extension Not Found**:
```sql
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
```

2. **Permission Denied**:
```sql
-- Ensure proper grants
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO wata_board_app;
```

3. **Migration Conflicts**:
```sql
-- Check migration status
SELECT * FROM system_config WHERE key LIKE 'migration_%';
```

4. **Performance Issues**:
```sql
-- Check missing indexes
SELECT * FROM pg_stat_user_indexes WHERE idx_scan = 0;

-- Update statistics
ANALYZE;
```

## Data Validation

After migrations, validate the schema:
```sql
-- Check all tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' AND table_type = 'BASE TABLE';

-- Check indexes
SELECT indexname, tablename FROM pg_indexes 
WHERE schemaname = 'public';

-- Check constraints
SELECT conname, conrelid::regclass FROM pg_constraint 
WHERE connamespace = 'public'::regnamespace;
```

## Security Notes

1. **Never commit sensitive data** like passwords or API keys
2. **Use environment variables** for configuration
3. **Enable SSL** for database connections in production
4. **Regular security audits** of user permissions
5. **Backup strategy** must be tested regularly

## Additional Resources

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Database Best Practices](https://wiki.postgresql.org/wiki/Main_Page)
- [Migration Tools](https://flywaydb.org/)
- [Performance Tuning](https://www.postgresql.org/docs/current/performance-tips.html)

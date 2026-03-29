# Wata Board Database Schema Documentation

## Overview

The Wata Board system utilizes a hybrid data storage approach:
1. **Stellar Blockchain** - Primary data storage for payments and meter records
2. **Traditional Database** - Proposed for caching, user management, and analytics

This document outlines both the existing blockchain data structures and the proposed traditional database schema.

## 1. Current Data Architecture

### 1.1 Stellar Blockchain Data Model

The application currently stores data on the Stellar blockchain through smart contracts with the following key data structures:

#### Smart Contract Methods
- `pay_bill({meter_id: string, amount: u32})` - Process utility payments
- `get_total_paid({meter_id: string})` - Retrieve total payments for a meter

#### Blockchain Data Storage
```
Contract ID: CDRRJ7IPYDL36YSK5ZQLBG3LICULETIBXX327AGJQNTWXNKY2UMDO4DA (Testnet)
Network: Stellar Soroban
Data Types:
- meter_id: string (identifier for utility meters)
- amount: u32 (payment amounts)
- transaction_hash: string (unique transaction identifiers)
```

### 1.2 In-Memory Data Structures

#### Payment Service
```typescript
interface PaymentRequest {
  meter_id: string;
  amount: number;
  userId: string;
}

// In-memory storage for pending payments
private pendingPayments: Map<string, PaymentRequest>
```

#### Rate Limiter
```typescript
interface RateLimitConfig {
  windowMs: number;
  maxRequests: number;
  queueSize: number;
}
```

## 2. Proposed Traditional Database Schema

### 2.1 Database Design Goals

1. **User Management** - Store user profiles and authentication data
2. **Payment Caching** - Cache blockchain transactions for faster access
3. **Analytics** - Enable comprehensive reporting and insights
4. **Audit Trail** - Maintain detailed logs of all operations
5. **Performance** - Reduce blockchain query overhead

### 2.2 Database Technology Stack

**Recommended:** PostgreSQL 14+
- ACID compliance for transaction integrity
- JSON support for flexible data storage
- Excellent performance for analytical queries
- Strong ecosystem and tooling

**Alternative:** MySQL 8.0+
- Mature and widely adopted
- Good performance characteristics
- Strong community support

### 2.3 Schema Design

#### 2.3.1 Users Table
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stellar_public_key VARCHAR(56) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_users_stellar_public_key ON users(stellar_public_key);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
```

#### 2.3.2 Meters Table
```sql
CREATE TABLE meters (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meter_id VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    meter_type VARCHAR(20) NOT NULL CHECK (meter_type IN ('electricity', 'water', 'gas')),
    utility_company VARCHAR(100),
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_meters_meter_id ON meters(meter_id);
CREATE INDEX idx_meters_user_id ON meters(user_id);
CREATE INDEX idx_meters_type ON meters(meter_type);
```

#### 2.3.3 Payments Table
```sql
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_hash VARCHAR(64) UNIQUE NOT NULL,
    meter_id VARCHAR(50) NOT NULL REFERENCES meters(meter_id),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(12, 2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'XLM',
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'confirmed', 'failed', 'queued')),
    blockchain_network VARCHAR(20) NOT NULL DEFAULT 'testnet',
    contract_id VARCHAR(56) NOT NULL,
    stellar_transaction_xdr TEXT,
    block_number BIGINT,
    block_timestamp TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb
);

CREATE INDEX idx_payments_transaction_hash ON payments(transaction_hash);
CREATE INDEX idx_payments_meter_id ON payments(meter_id);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at);
CREATE INDEX idx_payments_amount ON payments(amount);
```

#### 2.3.4 Payment Cache Table
```sql
CREATE TABLE payment_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    meter_id VARCHAR(50) NOT NULL,
    total_paid DECIMAL(12, 2) NOT NULL DEFAULT 0,
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    cache_expiry TIMESTAMP WITH TIME ZONE NOT NULL,
    blockchain_network VARCHAR(20) NOT NULL DEFAULT 'testnet'
);

CREATE UNIQUE INDEX idx_payment_cache_meter_network ON payment_cache(meter_id, blockchain_network);
CREATE INDEX idx_payment_cache_expiry ON payment_cache(cache_expiry);
```

#### 2.3.5 Rate Limits Table
```sql
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    window_start TIMESTAMP WITH TIME ZONE NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0,
    window_duration_ms INTEGER NOT NULL DEFAULT 60000,
    max_requests INTEGER NOT NULL DEFAULT 5,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_rate_limits_user_window ON rate_limits(user_id, window_start);
```

#### 2.3.6 Audit Logs Table
```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    action VARCHAR(50) NOT NULL,
    resource_type VARCHAR(50) NOT NULL,
    resource_id VARCHAR(50),
    old_values JSONB,
    new_values JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);
```

#### 2.3.7 System Configuration Table
```sql
CREATE TABLE system_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_system_config_key ON system_config(key);
```

## 3. Data Relationships

### 3.1 Entity Relationship Diagram

```
Users (1) -----> (N) Meters
  |                     |
  |                     |
 (N)                   (N)
  |                     |
Payments (N) <--------- (1) Meters
  |
  |
 (1)
Payment Cache

Users (1) -----> (N) Rate Limits
Users (1) -----> (N) Audit Logs
```

### 3.2 Key Relationships

1. **Users to Meters**: One-to-many relationship
2. **Meters to Payments**: One-to-many relationship
3. **Users to Payments**: One-to-many relationship
4. **Payment Cache**: Aggregated data per meter
5. **Audit Logs**: Track all user actions

## 4. Data Flow Architecture

### 4.1 Payment Processing Flow

```
1. User initiates payment request
2. Rate limit check (database)
3. Payment record created (status: pending)
4. Stellar blockchain transaction
5. Transaction confirmation
6. Payment record updated (status: confirmed)
7. Payment cache updated
8. Audit log created
```

### 4.2 Data Synchronization

```
Blockchain -> Database Cache
- Real-time transaction monitoring
- Periodic reconciliation
- Cache invalidation strategies
```

## 5. Performance Considerations

### 5.1 Indexing Strategy

- **Primary Keys**: UUID indexes for all tables
- **Foreign Keys**: Indexed for join performance
- **Query Patterns**: Composite indexes for common queries
- **Time-based**: Indexes on timestamp columns

### 5.2 Partitioning

```sql
-- Partition payments table by month for better performance
CREATE TABLE payments_y2024m01 PARTITION OF payments
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');
```

### 5.3 Caching Strategy

- **Redis**: Session management and rate limiting
- **Application Cache**: Frequently accessed meter data
- **Database Cache**: Query result caching

## 6. Security Considerations

### 6.1 Data Encryption

- **At Rest**: Transparent Data Encryption (TDE)
- **In Transit**: TLS 1.3 for all connections
- **Sensitive Data**: Column-level encryption for PII

### 6.2 Access Control

```sql
-- Row Level Security for user data
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY user_payments ON payments
FOR ALL TO application_user
USING (user_id = current_user_id());
```

### 6.3 Audit Trail

- Complete audit logging for all data modifications
- Immutable log records
- Regular backup and verification

## 7. Backup and Recovery

### 7.1 Backup Strategy

- **Daily Full Backups**: Complete database backup
- **Hourly Incremental**: Transaction log backups
- **Point-in-Time Recovery**: 15-minute RPO
- **Cross-Region Replication**: Disaster recovery

### 7.2 Data Retention

- **Payments**: 7 years (regulatory requirement)
- **Audit Logs**: 3 years
- **Rate Limits**: 30 days
- **Cache Data**: 24 hours

## 8. Migration Strategy

### 8.1 Phase 1: Database Setup
1. Create database schema
2. Set up replication and backup
3. Configure monitoring and alerting

### 8.2 Phase 2: Data Migration
1. Migrate existing user data (if any)
2. Set up blockchain transaction monitoring
3. Populate cache tables with historical data

### 8.3 Phase 3: Application Integration
1. Update application to use database
2. Implement caching layer
3. Add comprehensive logging

## 9. Monitoring and Maintenance

### 9.1 Key Metrics

- Database connection pool usage
- Query performance metrics
- Cache hit rates
- Blockchain sync status

### 9.2 Maintenance Tasks

- Daily: Backup verification
- Weekly: Performance tuning
- Monthly: Index maintenance
- Quarterly: Schema review

## 10. Environment Configuration

### 10.1 Development Environment
```sql
-- Development database configuration
DATABASE_URL=postgresql://user:pass@localhost:5432/wata_board_dev
REDIS_URL=redis://localhost:6379/0
```

### 10.2 Production Environment
```sql
-- Production database configuration
DATABASE_URL=postgresql://user:pass@prod-db:5432/wata_board_prod
REDIS_URL=redis://prod-redis:6379/0
SSL_MODE=require
```

## 11. API Integration Points

### 11.1 Database Endpoints

```typescript
// User management
POST /api/users
GET /api/users/:id
PUT /api/users/:id

// Payment operations
POST /api/payments
GET /api/payments/:id
GET /api/meters/:meterId/payments

// Analytics
GET /api/analytics/payments
GET /api/analytics/users
```

### 11.2 Cache Management

```typescript
// Cache operations
GET /api/cache/meters/:meterId/total
POST /api/cache/refresh
DELETE /api/cache/:key
```

This comprehensive database schema provides a solid foundation for scaling the Wata Board application while maintaining data integrity and performance.

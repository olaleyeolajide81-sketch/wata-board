-- Wata Board Database Migration - Enhanced Indexes and Constraints
-- Version: 002
-- Description: Adds additional indexes, constraints, and optimizations
-- Created: 2025-03-25
-- Depends on: 001_initial_schema.sql

-- Add composite indexes for common query patterns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_user_status_created 
ON payments(user_id, status, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_meter_status_created 
ON payments(meter_id, status, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_network_status_created 
ON payments(blockchain_network, status, created_at DESC);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_meters_user_active_type 
ON meters(user_id, is_active, meter_type);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_user_action_created 
ON audit_logs(user_id, action, created_at DESC);

-- Add partial indexes for better performance
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_pending 
ON payments(created_at) WHERE status = 'pending';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_confirmed 
ON payments(confirmed_at) WHERE status = 'confirmed' AND confirmed_at IS NOT NULL;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_active 
ON users(created_at) WHERE is_active = true;

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_meters_active 
ON meters(created_at) WHERE is_active = true;

-- Add GIN indexes for JSONB columns
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_metadata_gin 
ON users USING GIN(metadata);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_metadata_gin 
ON payments USING GIN(metadata);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_meters_metadata_gin 
ON meters USING GIN(metadata);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_old_values_gin 
ON audit_logs USING GIN(old_values);

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_audit_logs_new_values_gin 
ON audit_logs USING GIN(new_values);

-- Add functional indexes for common calculations
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_amount_status 
ON payments(amount, status) WHERE status = 'confirmed';

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_users_created_month 
ON users(DATE_TRUNC('month', created_at));

CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_payments_created_month 
ON payments(DATE_TRUNC('month', created_at));

-- Add table partitioning for payments (if needed for large datasets)
-- This is commented out by default - uncomment if you expect high volume
/*
-- Create partitioned table for payments
CREATE TABLE payments_partitioned (
    LIKE payments INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Create monthly partitions
CREATE TABLE payments_y2024m01 PARTITION OF payments_partitioned
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

CREATE TABLE payments_y2024m02 PARTITION OF payments_partitioned
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01');

-- Add function to create future partitions automatically
CREATE OR REPLACE FUNCTION create_monthly_partitions(table_name text, start_date date, end_date date)
RETURNS void AS $$
DECLARE
    current_date date := start_date;
    partition_name text;
    start_timestamp timestamp;
    end_timestamp timestamp;
BEGIN
    WHILE current_date <= end_date LOOP
        partition_name := table_name || '_y' || EXTRACT(year FROM current_date) || 'm' || LPAD(EXTRACT(month FROM current_date)::text, 2, '0');
        start_timestamp := date_trunc('month', current_date);
        end_timestamp := start_timestamp + INTERVAL '1 month';
        
        EXECUTE format('CREATE TABLE IF NOT EXISTS %I PARTITION OF %I FOR VALUES FROM (%L) TO (%L)',
                      partition_name, table_name, start_timestamp, end_timestamp);
        
        current_date := current_date + INTERVAL '1 month';
    END LOOP;
END;
$$ LANGUAGE plpgsql;
*/

-- Add check constraints for data integrity
ALTER TABLE payments 
ADD CONSTRAINT IF NOT EXISTS payments_amount_range 
CHECK (amount BETWEEN 0.01 AND 999999.99);

ALTER TABLE payments 
ADD CONSTRAINT IF NOT EXISTS payments_currency_format 
CHECK (currency ~ '^[A-Z]{3}$');

ALTER TABLE rate_limits 
ADD CONSTRAINT IF NOT EXISTS rate_limits_request_count_valid 
CHECK (request_count <= max_requests);

ALTER TABLE users 
ADD CONSTRAINT IF NOT EXISTS users_phone_format 
CHECK (phone IS NULL OR phone ~ '^\+?[1-9]\d{1,14}$');

-- Add unique constraints for business logic
ALTER TABLE meters 
ADD CONSTRAINT IF NOT EXISTS meters_unique_user_meter 
UNIQUE (user_id, meter_id);

-- Add exclusion constraints for overlapping rate limit windows
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint 
        WHERE conname = 'rate_limits_no_overlapping_windows'
    ) THEN
        ALTER TABLE rate_limits 
        ADD CONSTRAINT rate_limits_no_overlapping_windows 
        EXCLUDE USING gist (
            user_id WITH =,
            tsrange(window_start, window_start + (window_duration_ms || ' milliseconds')::interval) WITH &&
        );
    END IF;
END $$;

-- Create materialized view for payment statistics
CREATE MATERIALIZED VIEW IF NOT EXISTS payment_statistics AS
SELECT 
    DATE_TRUNC('day', created_at) as payment_date,
    blockchain_network,
    COUNT(*) as total_transactions,
    COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_transactions,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_transactions,
    COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_transactions,
    SUM(amount) FILTER (WHERE status = 'confirmed') as total_amount,
    AVG(amount) FILTER (WHERE status = 'confirmed') as average_amount,
    MIN(amount) FILTER (WHERE status = 'confirmed') as min_amount,
    MAX(amount) FILTER (WHERE status = 'confirmed') as max_amount
FROM payments
GROUP BY DATE_TRUNC('day', created_at), blockchain_network
ORDER BY payment_date DESC;

-- Create unique index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_payment_statistics_unique 
ON payment_statistics(payment_date, blockchain_network);

-- Create function to refresh materialized view
CREATE OR REPLACE FUNCTION refresh_payment_statistics()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY payment_statistics;
END;
$$ LANGUAGE plpgsql;

-- Add trigger to automatically refresh stats (optional - may impact performance)
/*
CREATE OR REPLACE FUNCTION auto_refresh_payment_stats()
RETURNS trigger AS $$
BEGIN
    -- Refresh stats every 10 minutes after payment changes
    -- This is a simplified approach - consider using a scheduled job instead
    PERFORM pg_notify('refresh_payment_stats', '1');
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_refresh_payment_stats
    AFTER INSERT OR UPDATE ON payments
    FOR EACH STATEMENT EXECUTE FUNCTION auto_refresh_payment_stats();
*/

-- Create enhanced analytics view
CREATE OR REPLACE VIEW enhanced_payment_analytics AS
SELECT 
    p.payment_month,
    p.meter_type,
    p.blockchain_network,
    p.total_payments,
    p.total_amount,
    p.average_amount,
    p.min_amount,
    p.max_amount,
    p.confirmed_payments,
    p.failed_payments,
    ROUND((p.confirmed_payments::DECIMAL / NULLIF(p.total_payments, 0)) * 100, 2) as success_rate,
    u.total_users as active_users,
    m.total_meters as active_meters,
    ROUND(p.total_amount / NULLIF(p.confirmed_payments, 0), 2) as avg_confirmed_amount
FROM payment_analytics p
LEFT JOIN (
    SELECT 
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as total_users
    FROM users
    WHERE is_active = true
    GROUP BY DATE_TRUNC('month', created_at)
) u ON p.payment_month = u.month
LEFT JOIN (
    SELECT 
        DATE_TRUNC('month', created_at) as month,
        COUNT(*) as total_meters
    FROM meters
    WHERE is_active = true
    GROUP BY DATE_TRUNC('month', created_at)
) m ON p.payment_month = m.month
ORDER BY p.payment_month DESC;

-- Create function for payment trend analysis
CREATE OR REPLACE FUNCTION get_payment_trends(
    p_start_date DATE DEFAULT CURRENT_DATE - INTERVAL '30 days',
    p_end_date DATE DEFAULT CURRENT_DATE,
    p_blockchain_network blockchain_network DEFAULT 'testnet'
)
RETURNS TABLE (
    date DATE,
    total_payments BIGINT,
    confirmed_payments BIGINT,
    failed_payments BIGINT,
    total_amount DECIMAL(12, 2),
    average_amount DECIMAL(12, 2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        DATE(created_at)::DATE as date,
        COUNT(*) as total_payments,
        COUNT(CASE WHEN status = 'confirmed' THEN 1 END) as confirmed_payments,
        COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed_payments,
        COALESCE(SUM(CASE WHEN status = 'confirmed' THEN amount END), 0) as total_amount,
        COALESCE(AVG(CASE WHEN status = 'confirmed' THEN amount END), 0) as average_amount
    FROM payments
    WHERE created_at >= p_start_date
    AND created_at <= p_end_date
    AND blockchain_network = p_blockchain_network
    GROUP BY DATE(created_at)
    ORDER BY date;
END;
$$ LANGUAGE plpgsql;

-- Create function for user payment summary
CREATE OR REPLACE FUNCTION get_user_payment_summary(p_user_id UUID)
RETURNS TABLE (
    total_meters BIGINT,
    total_payments BIGINT,
    confirmed_payments BIGINT,
    failed_payments BIGINT,
    total_spent DECIMAL(12, 2),
    average_payment DECIMAL(12, 2),
    last_payment_date TIMESTAMP WITH TIME ZONE,
    most_used_meter_type VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(DISTINCT m.id) as total_meters,
        COUNT(DISTINCT p.id) as total_payments,
        COUNT(DISTINCT CASE WHEN p.status = 'confirmed' THEN p.id END) as confirmed_payments,
        COUNT(DISTINCT CASE WHEN p.status = 'failed' THEN p.id END) as failed_payments,
        COALESCE(SUM(CASE WHEN p.status = 'confirmed' THEN p.amount END), 0) as total_spent,
        COALESCE(AVG(CASE WHEN p.status = 'confirmed' THEN p.amount END), 0) as average_payment,
        MAX(p.created_at) as last_payment_date,
        mode() WITHIN GROUP (ORDER BY m.meter_type) as most_used_meter_type
    FROM users u
    LEFT JOIN meters m ON u.id = m.user_id
    LEFT JOIN payments p ON u.id = p.user_id
    WHERE u.id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- Add table comments for documentation
COMMENT ON TABLE users IS 'User accounts and authentication information';
COMMENT ON TABLE meters IS 'Utility meters registered in the system';
COMMENT ON TABLE payments IS 'Payment transactions processed through the system';
COMMENT ON TABLE payment_cache IS 'Cached total payments per meter for performance';
COMMENT ON TABLE rate_limits IS 'Rate limiting information for API requests';
COMMENT ON TABLE audit_logs IS 'Audit trail for all system operations';
COMMENT ON TABLE system_config IS 'System configuration parameters';

-- Add column comments for important fields
COMMENT ON COLUMN users.stellar_public_key IS 'User Stellar wallet public key';
COMMENT ON COLUMN users.metadata IS 'Additional user information in JSON format';
COMMENT ON COLUMN payments.transaction_hash IS 'Stellar blockchain transaction hash';
COMMENT ON COLUMN payments.stellar_transaction_xdr IS 'Stellar transaction in XDR format';
COMMENT ON COLUMN payments.metadata IS 'Additional payment information in JSON format';
COMMENT ON COLUMN meters.metadata IS 'Additional meter information in JSON format';

-- Create function to clean up old audit logs
CREATE OR REPLACE FUNCTION cleanup_old_audit_logs(
    p_retention_days INTEGER DEFAULT 90
)
RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM audit_logs 
    WHERE created_at < CURRENT_TIMESTAMP - INTERVAL '1 day' * p_retention_days;
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    -- Log the cleanup
    INSERT INTO audit_logs (action, resource_type, resource_id, new_values)
    VALUES ('cleanup', 'audit_logs', v_deleted_count::TEXT, 
            jsonb_build_object('retention_days', p_retention_days, 'deleted_count', v_deleted_count));
    
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to clean up expired rate limits
CREATE OR REPLACE FUNCTION cleanup_expired_rate_limits()
RETURNS INTEGER AS $$
DECLARE
    v_deleted_count INTEGER;
BEGIN
    DELETE FROM rate_limits 
    WHERE window_start < CURRENT_TIMESTAMP - INTERVAL '1 day';
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    
    RETURN v_deleted_count;
END;
$$ LANGUAGE plpgsql;

-- Create function to optimize table statistics
CREATE OR REPLACE FUNCTION update_table_statistics()
RETURNS void AS $$
BEGIN
    ANALYZE users;
    ANALYZE meters;
    ANALYZE payments;
    ANALYZE payment_cache;
    ANALYZE rate_limits;
    ANALYZE audit_logs;
    ANALYZE system_config;
    ANALYZE payment_statistics;
END;
$$ LANGUAGE plpgsql;

-- Record migration completion
INSERT INTO system_config (key, value, description) VALUES
('migration_002_indexes_constraints', '"completed"', 'Enhanced indexes and constraints migration completed at ' || CURRENT_TIMESTAMP);

COMMIT;

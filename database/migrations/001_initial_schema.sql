-- Wata Board Database Migration - Initial Schema
-- Version: 001
-- Description: Creates the initial database schema for Wata Board application
-- Created: 2025-03-25

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Enable JSONB extension (available by default in PostgreSQL 13+)
-- CREATE EXTENSION IF NOT EXISTS "btree_gin"; -- For GIN index on JSONB

-- Create custom types
CREATE TYPE meter_type AS ENUM ('electricity', 'water', 'gas');
CREATE TYPE payment_status AS ENUM ('pending', 'confirmed', 'failed', 'queued');
CREATE TYPE blockchain_network AS ENUM ('testnet', 'mainnet');

-- Create users table
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    stellar_public_key VARCHAR(56) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    phone VARCHAR(20),
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT true,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Constraints
    CONSTRAINT users_stellar_public_key_format CHECK (stellar_public_key ~ '^G[A-Z0-9]{55}$'),
    CONSTRAINT users_email_format CHECK (email IS NULL OR email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Create meters table
CREATE TABLE meters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meter_id VARCHAR(50) UNIQUE NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    meter_type meter_type NOT NULL,
    utility_company VARCHAR(100),
    address TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Constraints
    CONSTRAINT meters_meter_id_format CHECK (meter_id ~ '^[A-Za-z0-9_-]+$')
);

-- Create payments table
CREATE TABLE payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_hash VARCHAR(64) UNIQUE NOT NULL,
    meter_id VARCHAR(50) NOT NULL,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(12, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) DEFAULT 'XLM',
    status payment_status NOT NULL DEFAULT 'pending',
    blockchain_network blockchain_network NOT NULL DEFAULT 'testnet',
    contract_id VARCHAR(56) NOT NULL,
    stellar_transaction_xdr TEXT,
    block_number BIGINT,
    block_timestamp TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    -- Foreign key constraint to meters table
    CONSTRAINT payments_meter_id_fkey FOREIGN KEY (meter_id) REFERENCES meters(meter_id) ON DELETE CASCADE,
    
    -- Constraints
    CONSTRAINT payments_transaction_hash_format CHECK (transaction_hash ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT payments_contract_id_format CHECK (contract_id ~ '^[A-Za-z0-9]{56}$')
);

-- Create payment_cache table
CREATE TABLE payment_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    meter_id VARCHAR(50) NOT NULL,
    total_paid DECIMAL(12, 2) NOT NULL DEFAULT 0 CHECK (total_paid >= 0),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    cache_expiry TIMESTAMP WITH TIME ZONE NOT NULL,
    blockchain_network blockchain_network NOT NULL DEFAULT 'testnet',
    
    -- Unique constraint
    CONSTRAINT payment_cache_unique_meter_network UNIQUE (meter_id, blockchain_network)
);

-- Create rate_limits table
CREATE TABLE rate_limits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    window_start TIMESTAMP WITH TIME ZONE NOT NULL,
    request_count INTEGER NOT NULL DEFAULT 0 CHECK (request_count >= 0),
    window_duration_ms INTEGER NOT NULL DEFAULT 60000 CHECK (window_duration_ms > 0),
    max_requests INTEGER NOT NULL DEFAULT 5 CHECK (max_requests > 0),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    -- Unique constraint
    CONSTRAINT rate_limits_unique_user_window UNIQUE (user_id, window_start)
);

-- Create audit_logs table
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
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

-- Create system_config table
CREATE TABLE system_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    key VARCHAR(100) UNIQUE NOT NULL,
    value JSONB NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for performance
-- Users table indexes
CREATE INDEX idx_users_stellar_public_key ON users(stellar_public_key);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_is_active ON users(is_active);

-- Meters table indexes
CREATE INDEX idx_meters_meter_id ON meters(meter_id);
CREATE INDEX idx_meters_user_id ON meters(user_id);
CREATE INDEX idx_meters_type ON meters(meter_type);
CREATE INDEX idx_meters_is_active ON meters(is_active);

-- Payments table indexes
CREATE INDEX idx_payments_transaction_hash ON payments(transaction_hash);
CREATE INDEX idx_payments_meter_id ON payments(meter_id);
CREATE INDEX idx_payments_user_id ON payments(user_id);
CREATE INDEX idx_payments_status ON payments(status);
CREATE INDEX idx_payments_created_at ON payments(created_at);
CREATE INDEX idx_payments_amount ON payments(amount);
CREATE INDEX idx_payments_blockchain_network ON payments(blockchain_network);
CREATE INDEX idx_payments_confirmed_at ON payments(confirmed_at);

-- Payment cache indexes
CREATE INDEX idx_payment_cache_meter_id ON payment_cache(meter_id);
CREATE INDEX idx_payment_cache_blockchain_network ON payment_cache(blockchain_network);
CREATE INDEX idx_payment_cache_expiry ON payment_cache(cache_expiry);

-- Rate limits indexes
CREATE INDEX idx_rate_limits_user_id ON rate_limits(user_id);
CREATE INDEX idx_rate_limits_window_start ON rate_limits(window_start);
CREATE INDEX idx_rate_limits_user_window ON rate_limits(user_id, window_start);

-- Audit logs indexes
CREATE INDEX idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX idx_audit_logs_action ON audit_logs(action);
CREATE INDEX idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX idx_audit_logs_created_at ON audit_logs(created_at);

-- System config indexes
CREATE INDEX idx_system_config_key ON system_config(key);
CREATE INDEX idx_system_config_is_active ON system_config(is_active);

-- Create triggers for automatic timestamp updates
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply triggers to tables with updated_at columns
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_meters_updated_at BEFORE UPDATE ON meters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_system_config_updated_at BEFORE UPDATE ON system_config
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create trigger for payment cache expiry
CREATE OR REPLACE FUNCTION update_payment_cache_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_updated = CURRENT_TIMESTAMP;
    NEW.cache_expiry = CURRENT_TIMESTAMP + INTERVAL '1 hour';
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_payment_cache_timestamp BEFORE INSERT OR UPDATE ON payment_cache
    FOR EACH ROW EXECUTE FUNCTION update_payment_cache_timestamp();

-- Insert default system configuration
INSERT INTO system_config (key, value, description) VALUES
('app_name', '"Wata Board"', 'Application name'),
('app_version', '"1.0.0"', 'Application version'),
('max_payment_amount', '10000.00', 'Maximum payment amount allowed'),
('default_currency', '"XLM"', 'Default currency for payments'),
('cache_expiry_minutes', '60', 'Cache expiry time in minutes'),
('rate_limit_window_ms', '60000', 'Rate limit window duration in milliseconds'),
('rate_limit_max_requests', '5', 'Maximum requests per rate limit window'),
('blockchain_network', '"testnet"', 'Default blockchain network'),
('contract_id_testnet', '"CDRRJ7IPYDL36YSK5ZQLBG3LICULETIBXX327AGJQNTWXNKY2UMDO4DA"', 'Testnet contract ID'),
('contract_id_mainnet', '""', 'Mainnet contract ID (to be configured)'),
('rpc_url_testnet', '"https://soroban-testnet.stellar.org"', 'Testnet RPC URL'),
('rpc_url_mainnet', '"https://soroban.stellar.org"', 'Mainnet RPC URL');

-- Create view for payment analytics
CREATE OR REPLACE VIEW payment_analytics AS
SELECT 
    DATE_TRUNC('month', p.created_at) as payment_month,
    m.meter_type,
    p.blockchain_network,
    COUNT(*) as total_payments,
    SUM(p.amount) as total_amount,
    AVG(p.amount) as average_amount,
    MIN(p.amount) as min_amount,
    MAX(p.amount) as max_amount,
    COUNT(CASE WHEN p.status = 'confirmed' THEN 1 END) as confirmed_payments,
    COUNT(CASE WHEN p.status = 'failed' THEN 1 END) as failed_payments
FROM payments p
JOIN meters m ON p.meter_id = m.meter_id
GROUP BY DATE_TRUNC('month', p.created_at), m.meter_type, p.blockchain_network
ORDER BY payment_month DESC;

-- Create view for user activity
CREATE OR REPLACE VIEW user_activity AS
SELECT 
    u.id,
    u.stellar_public_key,
    u.email,
    u.full_name,
    u.created_at as user_created_at,
    u.last_login,
    COUNT(DISTINCT m.id) as total_meters,
    COUNT(DISTINCT p.id) as total_payments,
    COALESCE(SUM(p.amount), 0) as total_spent,
    MAX(p.created_at) as last_payment_date,
    COUNT(DISTINCT al.id) as total_actions
FROM users u
LEFT JOIN meters m ON u.id = m.user_id
LEFT JOIN payments p ON u.id = p.user_id
LEFT JOIN audit_logs al ON u.id = al.user_id
GROUP BY u.id, u.stellar_public_key, u.email, u.full_name, u.created_at, u.last_login
ORDER BY u.created_at DESC;

-- Create function to get total paid amount for a meter (with caching)
CREATE OR REPLACE FUNCTION get_meter_total_paid(
    p_meter_id VARCHAR(50),
    p_blockchain_network blockchain_network DEFAULT 'testnet'
)
RETURNS DECIMAL(12, 2) AS $$
DECLARE
    v_total_paid DECIMAL(12, 2);
    v_cache_exists BOOLEAN;
BEGIN
    -- Check if cache exists and is not expired
    SELECT EXISTS(
        SELECT 1 FROM payment_cache 
        WHERE meter_id = p_meter_id 
        AND blockchain_network = p_blockchain_network 
        AND cache_expiry > CURRENT_TIMESTAMP
    ) INTO v_cache_exists;
    
    IF v_cache_exists THEN
        -- Return cached value
        SELECT total_paid INTO v_total_paid
        FROM payment_cache
        WHERE meter_id = p_meter_id 
        AND blockchain_network = p_blockchain_network;
    ELSE
        -- Calculate from payments table
        SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
        FROM payments
        WHERE meter_id = p_meter_id
        AND blockchain_network = p_blockchain_network
        AND status = 'confirmed';
        
        -- Update cache
        INSERT INTO payment_cache (meter_id, total_paid, blockchain_network)
        VALUES (p_meter_id, v_total_paid, p_blockchain_network)
        ON CONFLICT (meter_id, blockchain_network)
        DO UPDATE SET 
            total_paid = EXCLUDED.total_paid,
            last_updated = CURRENT_TIMESTAMP,
            cache_expiry = CURRENT_TIMESTAMP + INTERVAL '1 hour';
    END IF;
    
    RETURN v_total_paid;
END;
$$ LANGUAGE plpgsql;

-- Create function to invalidate payment cache
CREATE OR REPLACE FUNCTION invalidate_payment_cache(p_meter_id VARCHAR(50))
RETURNS VOID AS $$
BEGIN
    UPDATE payment_cache
    SET cache_expiry = CURRENT_TIMESTAMP - INTERVAL '1 second'
    WHERE meter_id = p_meter_id;
END;
$$ LANGUAGE plpgsql;

-- Create trigger to invalidate cache when payment is confirmed
CREATE OR REPLACE FUNCTION invalidate_cache_on_payment()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'confirmed' AND (OLD.status IS NULL OR OLD.status != 'confirmed') THEN
        PERFORM invalidate_payment_cache(NEW.meter_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER invalidate_payment_cache_trigger
    AFTER UPDATE ON payments
    FOR EACH ROW EXECUTE FUNCTION invalidate_cache_on_payment();

-- Create trigger to invalidate cache on new payment
CREATE TRIGGER invalidate_payment_cache_insert
    AFTER INSERT ON payments
    FOR EACH ROW EXECUTE FUNCTION invalidate_cache_on_payment();

-- Grant permissions (adjust as needed for your environment)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO wata_board_app;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO wata_board_app;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO wata_board_app;

-- Create read-only user for analytics
-- CREATE USER wata_board_readonly WITH PASSWORD 'secure_password';
-- GRANT SELECT ON ALL TABLES IN SCHEMA public TO wata_board_readonly;
-- GRANT SELECT ON ALL VIEWS IN SCHEMA public TO wata_board_readonly;

-- Migration completed successfully
-- Record migration
INSERT INTO system_config (key, value, description) VALUES
('migration_001_initial_schema', '"completed"', 'Initial schema migration completed at ' || CURRENT_TIMESTAMP);

COMMIT;

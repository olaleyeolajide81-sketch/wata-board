-- Wata Board Database Migration - Blockchain Integration
-- Version: 003
-- Description: Adds blockchain-specific tables and integration features
-- Created: 2025-03-25
-- Depends on: 001_initial_schema.sql, 002_add_indexes_and_constraints.sql

-- Create blockchain_transactions table for detailed tracking
CREATE TABLE blockchain_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_hash VARCHAR(64) UNIQUE NOT NULL,
    payment_id UUID REFERENCES payments(id) ON DELETE CASCADE,
    stellar_public_key VARCHAR(56) NOT NULL,
    network blockchain_network NOT NULL,
    contract_id VARCHAR(56) NOT NULL,
    transaction_xdr TEXT NOT NULL,
    transaction_envelope_xdr TEXT,
    result_xdr TEXT,
    result_meta_xdr TEXT,
    status VARCHAR(20) NOT NULL CHECK (status IN ('pending', 'success', 'failed', 'timeout')),
    block_number BIGINT,
    block_timestamp TIMESTAMP WITH TIME ZONE,
    fee_paid DECIMAL(12, 7) DEFAULT 0,
    operations_count INTEGER DEFAULT 1,
    memo TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP WITH TIME ZONE,
    metadata JSONB DEFAULT '{}'::jsonb,
    
    CONSTRAINT blockchain_tx_hash_format CHECK (transaction_hash ~ '^[a-fA-F0-9]{64}$'),
    CONSTRAINT blockchain_public_key_format CHECK (stellar_public_key ~ '^G[A-Z0-9]{55}$')
);

-- Create blockchain_sync_status table for tracking synchronization
CREATE TABLE blockchain_sync_status (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network blockchain_network NOT NULL UNIQUE,
    contract_id VARCHAR(56) NOT NULL,
    last_synced_block BIGINT DEFAULT 0,
    latest_block BIGINT DEFAULT 0,
    sync_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (sync_status IN ('pending', 'syncing', 'completed', 'error')),
    error_message TEXT,
    last_sync_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    sync_interval_minutes INTEGER DEFAULT 5,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- Create smart_contract_events table for event logging
CREATE TABLE smart_contract_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transaction_hash VARCHAR(64) NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    contract_id VARCHAR(56) NOT NULL,
    network blockchain_network NOT NULL,
    block_number BIGINT,
    block_timestamp TIMESTAMP WITH TIME ZONE,
    event_data JSONB NOT NULL,
    topics TEXT[],
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    processed BOOLEAN DEFAULT false,
    processed_at TIMESTAMP WITH TIME ZONE,
    
    CONSTRAINT sc_events_tx_hash_format CHECK (transaction_hash ~ '^[a-fA-F0-9]{64}$')
);

-- Create blockchain_analytics table for performance metrics
CREATE TABLE blockchain_analytics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    network blockchain_network NOT NULL,
    metric_date DATE NOT NULL,
    total_transactions BIGINT DEFAULT 0,
    successful_transactions BIGINT DEFAULT 0,
    failed_transactions BIGINT DEFAULT 0,
    total_fees DECIMAL(12, 7) DEFAULT 0,
    average_fee DECIMAL(12, 7) DEFAULT 0,
    average_confirmation_time_seconds DECIMAL(10, 2) DEFAULT 0,
    total_amount DECIMAL(12, 2) DEFAULT 0,
    unique_users BIGINT DEFAULT 0,
    unique_meters BIGINT DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT blockchain_analytics_unique UNIQUE (network, metric_date)
);

-- Create indexes for blockchain tables
CREATE INDEX idx_blockchain_transactions_hash ON blockchain_transactions(transaction_hash);
CREATE INDEX idx_blockchain_transactions_payment_id ON blockchain_transactions(payment_id);
CREATE INDEX idx_blockchain_transactions_network_status ON blockchain_transactions(network, status);
CREATE INDEX idx_blockchain_transactions_created_at ON blockchain_transactions(created_at);
CREATE INDEX idx_blockchain_transactions_confirmed_at ON blockchain_transactions(confirmed_at);
CREATE INDEX idx_blockchain_transactions_stellar_key ON blockchain_transactions(stellar_public_key);

CREATE INDEX idx_blockchain_sync_status_network ON blockchain_sync_status(network);
CREATE INDEX idx_blockchain_sync_status_status ON blockchain_sync_status(sync_status);
CREATE INDEX idx_blockchain_sync_status_last_sync ON blockchain_sync_status(last_sync_at);

CREATE INDEX idx_smart_contract_events_tx_hash ON smart_contract_events(transaction_hash);
CREATE INDEX idx_smart_contract_events_contract_network ON smart_contract_events(contract_id, network);
CREATE INDEX idx_smart_contract_events_type ON smart_contract_events(event_type);
CREATE INDEX idx_smart_contract_events_processed ON smart_contract_events(processed);
CREATE INDEX idx_smart_contract_events_created_at ON smart_contract_events(created_at);

CREATE INDEX idx_blockchain_analytics_network_date ON blockchain_analytics(network, metric_date);
CREATE INDEX idx_blockchain_analytics_date ON blockchain_analytics(metric_date);

-- Create triggers for blockchain_transactions
CREATE TRIGGER update_blockchain_transactions_updated_at 
    BEFORE UPDATE ON blockchain_transactions 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_blockchain_sync_status_updated_at 
    BEFORE UPDATE ON blockchain_sync_status 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_blockchain_analytics_updated_at 
    BEFORE UPDATE ON blockchain_analytics 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Create function to record blockchain transaction
CREATE OR REPLACE FUNCTION record_blockchain_transaction(
    p_transaction_hash VARCHAR(64),
    p_payment_id UUID,
    p_stellar_public_key VARCHAR(56),
    p_network blockchain_network,
    p_contract_id VARCHAR(56),
    p_transaction_xdr TEXT,
    p_status VARCHAR(20) DEFAULT 'pending'
)
RETURNS UUID AS $$
DECLARE
    v_tx_id UUID;
BEGIN
    INSERT INTO blockchain_transactions (
        transaction_hash, payment_id, stellar_public_key, network, 
        contract_id, transaction_xdr, status
    ) VALUES (
        p_transaction_hash, p_payment_id, p_stellar_public_key, p_network,
        p_contract_id, p_transaction_xdr, p_status
    ) RETURNING id INTO v_tx_id;
    
    RETURN v_tx_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update blockchain transaction status
CREATE OR REPLACE FUNCTION update_blockchain_transaction_status(
    p_transaction_hash VARCHAR(64),
    p_status VARCHAR(20),
    p_block_number BIGINT DEFAULT NULL,
    p_block_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NULL,
    p_result_xdr TEXT DEFAULT NULL,
    p_result_meta_xdr TEXT DEFAULT NULL,
    p_fee_paid DECIMAL(12, 7) DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated BOOLEAN := FALSE;
BEGIN
    UPDATE blockchain_transactions 
    SET 
        status = p_status,
        block_number = p_block_number,
        block_timestamp = p_block_timestamp,
        result_xdr = p_result_xdr,
        result_meta_xdr = p_result_meta_xdr,
        fee_paid = COALESCE(p_fee_paid, fee_paid),
        confirmed_at = CASE WHEN p_status = 'success' THEN CURRENT_TIMESTAMP ELSE confirmed_at END,
        updated_at = CURRENT_TIMESTAMP
    WHERE transaction_hash = p_transaction_hash;
    
    v_updated := FOUND;
    
    -- Update corresponding payment status
    IF v_updated AND p_status = 'success' THEN
        UPDATE payments 
        SET status = 'confirmed', confirmed_at = CURRENT_TIMESTAMP
        WHERE transaction_hash = p_transaction_hash;
    ELSIF v_updated AND p_status = 'failed' THEN
        UPDATE payments 
        SET status = 'failed'
        WHERE transaction_hash = p_transaction_hash;
    END IF;
    
    RETURN v_updated;
END;
$$ LANGUAGE plpgsql;

-- Create function to record smart contract event
CREATE OR REPLACE FUNCTION record_smart_contract_event(
    p_transaction_hash VARCHAR(64),
    p_event_type VARCHAR(50),
    p_contract_id VARCHAR(56),
    p_network blockchain_network,
    p_event_data JSONB,
    p_topics TEXT[] DEFAULT NULL,
    p_block_number BIGINT DEFAULT NULL,
    p_block_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_event_id UUID;
BEGIN
    INSERT INTO smart_contract_events (
        transaction_hash, event_type, contract_id, network,
        event_data, topics, block_number, block_timestamp
    ) VALUES (
        p_transaction_hash, p_event_type, p_contract_id, p_network,
        p_event_data, p_topics, p_block_number, p_block_timestamp
    ) RETURNING id INTO v_event_id;
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- Create function to update blockchain sync status
CREATE OR REPLACE FUNCTION update_blockchain_sync_status(
    p_network blockchain_network,
    p_contract_id VARCHAR(56),
    p_last_synced_block BIGINT,
    p_latest_block BIGINT DEFAULT NULL,
    p_sync_status VARCHAR(20) DEFAULT 'completed',
    p_error_message TEXT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO blockchain_sync_status (
        network, contract_id, last_synced_block, latest_block, sync_status, error_message
    ) VALUES (
        p_network, p_contract_id, p_last_synced_block, p_latest_block, p_sync_status, p_error_message
    ) ON CONFLICT (network) DO UPDATE SET
        contract_id = EXCLUDED.contract_id,
        last_synced_block = EXCLUDED.last_synced_block,
        latest_block = COALESCE(EXCLUDED.latest_block, blockchain_sync_status.latest_block),
        sync_status = EXCLUDED.sync_status,
        error_message = EXCLUDED.error_message,
        last_sync_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Create function to process smart contract events
CREATE OR REPLACE FUNCTION process_smart_contract_events()
RETURNS INTEGER AS $$
DECLARE
    v_processed_count INTEGER := 0;
    v_event RECORD;
BEGIN
    FOR v_event IN 
        SELECT id, event_type, event_data, transaction_hash
        FROM smart_contract_events
        WHERE processed = false
        ORDER BY created_at
        LIMIT 1000  -- Process in batches
    LOOP
        -- Process different event types
        CASE v_event.event_type
            WHEN 'payment_completed' THEN
                -- Handle payment completion event
                PERFORM handle_payment_completed_event(v_event.event_data, v_event.transaction_hash);
            WHEN 'meter_registered' THEN
                -- Handle meter registration event
                PERFORM handle_meter_registered_event(v_event.event_data);
            WHEN 'user_verified' THEN
                -- Handle user verification event
                PERFORM handle_user_verified_event(v_event.event_data);
            ELSE
                -- Log unknown event type
                INSERT INTO audit_logs (action, resource_type, resource_id, new_values)
                VALUES ('unknown_event', 'smart_contract_events', v_event.id::TEXT, 
                        jsonb_build_object('event_type', v_event.event_type));
        END CASE;
        
        -- Mark as processed
        UPDATE smart_contract_events 
        SET processed = true, processed_at = CURRENT_TIMESTAMP
        WHERE id = v_event.id;
        
        v_processed_count := v_processed_count + 1;
    END LOOP;
    
    RETURN v_processed_count;
END;
$$ LANGUAGE plpgsql;

-- Create event handler functions
CREATE OR REPLACE FUNCTION handle_payment_completed_event(
    p_event_data JSONB,
    p_transaction_hash VARCHAR(64)
)
RETURNS VOID AS $$
BEGIN
    -- Update payment cache
    IF p_event_data ? 'meter_id' THEN
        PERFORM invalidate_payment_cache(p_event_data->>'meter_id');
    END IF;
    
    -- Log successful payment processing
    INSERT INTO audit_logs (action, resource_type, resource_id, new_values)
    VALUES ('payment_processed', 'blockchain_transaction', p_transaction_hash, p_event_data);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_meter_registered_event(p_event_data JSONB)
RETURNS VOID AS $$
BEGIN
    -- Handle meter registration from blockchain
    INSERT INTO audit_logs (action, resource_type, resource_id, new_values)
    VALUES ('meter_registered', 'blockchain_event', NULL, p_event_data);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION handle_user_verified_event(p_event_data JSONB)
RETURNS VOID AS $$
BEGIN
    -- Handle user verification from blockchain
    IF p_event_data ? 'stellar_public_key' THEN
        UPDATE users 
        SET is_verified = true, updated_at = CURRENT_TIMESTAMP
        WHERE stellar_public_key = p_event_data->>'stellar_public_key';
    END IF;
    
    INSERT INTO audit_logs (action, resource_type, resource_id, new_values)
    VALUES ('user_verified', 'blockchain_event', NULL, p_event_data);
END;
$$ LANGUAGE plpgsql;

-- Create function to generate blockchain analytics
CREATE OR REPLACE FUNCTION generate_blockchain_analytics(
    p_network blockchain_network DEFAULT 'testnet',
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS VOID AS $$
DECLARE
    v_total_tx BIGINT;
    v_successful_tx BIGINT;
    v_failed_tx BIGINT;
    v_total_fees DECIMAL(12, 7);
    v_avg_fee DECIMAL(12, 7);
    v_avg_confirmation_time DECIMAL(10, 2);
    v_total_amount DECIMAL(12, 2);
    v_unique_users BIGINT;
    v_unique_meters BIGINT;
BEGIN
    -- Calculate metrics
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN status = 'success' THEN 1 END),
        COUNT(CASE WHEN status = 'failed' THEN 1 END),
        COALESCE(SUM(fee_paid), 0),
        COALESCE(AVG(fee_paid), 0),
        COALESCE(AVG(EXTRACT(EPOCH FROM (confirmed_at - created_at))), 0)
    INTO v_total_tx, v_successful_tx, v_failed_tx, v_total_fees, v_avg_fee, v_avg_confirmation_time
    FROM blockchain_transactions
    WHERE network = p_network
    AND DATE(created_at) = p_date;
    
    -- Calculate total amount and unique counts
    SELECT 
        COALESCE(SUM(p.amount), 0),
        COUNT(DISTINCT p.user_id),
        COUNT(DISTINCT p.meter_id)
    INTO v_total_amount, v_unique_users, v_unique_meters
    FROM payments p
    JOIN blockchain_transactions bt ON p.transaction_hash = bt.transaction_hash
    WHERE bt.network = p_network
    AND DATE(p.created_at) = p_date
    AND p.status = 'confirmed';
    
    -- Insert or update analytics
    INSERT INTO blockchain_analytics (
        network, metric_date, total_transactions, successful_transactions, failed_transactions,
        total_fees, average_fee, average_confirmation_time_seconds, total_amount,
        unique_users, unique_meters
    ) VALUES (
        p_network, p_date, v_total_tx, v_successful_tx, v_failed_tx,
        v_total_fees, v_avg_fee, v_avg_confirmation_time, v_total_amount,
        v_unique_users, v_unique_meters
    ) ON CONFLICT (network, metric_date) DO UPDATE SET
        total_transactions = EXCLUDED.total_transactions,
        successful_transactions = EXCLUDED.successful_transactions,
        failed_transactions = EXCLUDED.failed_transactions,
        total_fees = EXCLUDED.total_fees,
        average_fee = EXCLUDED.average_fee,
        average_confirmation_time_seconds = EXCLUDED.average_confirmation_time_seconds,
        total_amount = EXCLUDED.total_amount,
        unique_users = EXCLUDED.unique_users,
        unique_meters = EXCLUDED.unique_meters,
        updated_at = CURRENT_TIMESTAMP;
END;
$$ LANGUAGE plpgsql;

-- Create view for blockchain transaction summary
CREATE OR REPLACE VIEW blockchain_transaction_summary AS
SELECT 
    DATE_TRUNC('day', bt.created_at) as transaction_date,
    bt.network,
    COUNT(*) as total_transactions,
    COUNT(CASE WHEN bt.status = 'success' THEN 1 END) as successful_transactions,
    COUNT(CASE WHEN bt.status = 'failed' THEN 1 END) as failed_transactions,
    COUNT(CASE WHEN bt.status = 'pending' THEN 1 END) as pending_transactions,
    COALESCE(SUM(bt.fee_paid), 0) as total_fees,
    COALESCE(AVG(bt.fee_paid), 0) as average_fee,
    COALESCE(AVG(EXTRACT(EPOCH FROM (bt.confirmed_at - bt.created_at))), 0) as avg_confirmation_time_seconds,
    COUNT(DISTINCT bt.stellar_public_key) as unique_addresses,
    COALESCE(SUM(p.amount), 0) as total_payment_amount
FROM blockchain_transactions bt
LEFT JOIN payments p ON bt.transaction_hash = p.transaction_hash
GROUP BY DATE_TRUNC('day', bt.created_at), bt.network
ORDER BY transaction_date DESC;

-- Create view for unprocessed events
CREATE OR REPLACE VIEW unprocessed_events AS
SELECT 
    id,
    transaction_hash,
    event_type,
    contract_id,
    network,
    event_data,
    created_at
FROM smart_contract_events
WHERE processed = false
ORDER BY created_at ASC;

-- Add table comments
COMMENT ON TABLE blockchain_transactions IS 'Detailed blockchain transaction records';
COMMENT ON TABLE blockchain_sync_status IS 'Blockchain synchronization status tracking';
COMMENT ON TABLE smart_contract_events IS 'Smart contract event logs';
COMMENT ON TABLE blockchain_analytics IS 'Blockchain performance and usage analytics';

-- Record migration completion
INSERT INTO system_config (key, value, description) VALUES
('migration_003_blockchain_integration', '"completed"', 'Blockchain integration migration completed at ' || CURRENT_TIMESTAMP);

COMMIT;

-- Add composite index for conflict count queries on sync_operation_logs.
-- The GetConflictCount query filters by user_id + operation_type + version=0.
CREATE INDEX CONCURRENTLY IF NOT EXISTS idx_sync_operation_logs_conflict
    ON sync_operation_logs (user_id, operation_type, version)
    WHERE operation_type = 'push' AND version = 0;

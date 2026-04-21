-- +migrate Up
CREATE TABLE sync_operation_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    operation_type VARCHAR(20) NOT NULL,
    item_type VARCHAR(50) NOT NULL,
    item_id UUID NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_sync_op_logs_user_id ON sync_operation_logs(user_id);
CREATE INDEX idx_sync_op_logs_created_at ON sync_operation_logs(created_at);

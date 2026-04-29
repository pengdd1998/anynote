CREATE TABLE stripe_webhook_events (
    event_id TEXT PRIMARY KEY,
    processed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_stripe_webhook_events_processed ON stripe_webhook_events(processed_at);

CREATE TABLE collab_operations (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid()::text,
    room_id TEXT NOT NULL REFERENCES collab_rooms(id) ON DELETE CASCADE,
    site_id TEXT NOT NULL,
    clock INTEGER NOT NULL DEFAULT 0,
    operation_type TEXT NOT NULL CHECK (operation_type IN ('insert', 'delete')),
    payload JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_collab_ops_room ON collab_operations(room_id, clock);
CREATE INDEX idx_collab_ops_site ON collab_operations(site_id);

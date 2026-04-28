CREATE TABLE collab_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    creator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code TEXT NOT NULL UNIQUE,
    room_name TEXT NOT NULL DEFAULT '',
    max_members INTEGER NOT NULL DEFAULT 10,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE collab_room_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES collab_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('owner', 'admin', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);

CREATE INDEX idx_collab_rooms_invite_code ON collab_rooms(invite_code);
CREATE INDEX idx_collab_rooms_creator ON collab_rooms(creator_id);
CREATE INDEX idx_collab_room_members_room ON collab_room_members(room_id);
CREATE INDEX idx_collab_room_members_user ON collab_room_members(user_id);

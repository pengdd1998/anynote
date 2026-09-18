-- Drop the collaboration feature tables. AnyNote is a personal notes app;
-- realtime multi-user collaboration (WS rooms, presence, CRDT relay) is not
-- a product feature and its backend was removed (see
-- doc/tech-plan-2026-09-deploy.md §2.11/§2.12).
--
-- FK order: collab_operations → collab_rooms, collab_room_members → collab_rooms;
-- both declare ON DELETE CASCADE, so dropping collab_rooms alone would suffice,
-- but explicit order keeps the intent obvious and works without CASCADE.
DROP TABLE IF EXISTS collab_operations;
DROP TABLE IF EXISTS collab_room_members;
DROP TABLE IF EXISTS collab_rooms;

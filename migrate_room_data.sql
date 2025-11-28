-- Transfer existing room data from JSONB to room_members table
-- This will migrate all existing rooms and their members

-- First, let's see what rooms we have
SELECT 
    id, 
    name, 
    members,
    jsonb_array_length(members) as member_count
FROM rooms 
WHERE members IS NOT NULL 
AND jsonb_array_length(members) > 0;

-- Check the structure of member data
SELECT 
    r.id,
    member
FROM rooms r,
    jsonb_array_elements(r.members) as member
WHERE r.members IS NOT NULL 
AND jsonb_array_length(members) > 0
LIMIT 5;

-- Check specific user_id values
SELECT 
    r.id,
    member->'user_id' as user_id_value,
    member->>'user_id' as user_id_text
FROM rooms r,
    jsonb_array_elements(r.members) as member
WHERE r.members IS NOT NULL 
AND jsonb_array_length(members) > 0
LIMIT 5;

-- Now migrate the data with proper UUID casting
INSERT INTO room_members (
    room_id, 
    user_id, 
    display_name, 
    avatar_url, 
    is_host, 
    is_ready, 
    is_spectator, 
    team,
    created_at
)
SELECT 
    r.id as room_id,
    (member->>'user_id')::uuid as user_id,
    member->>'display_name' as display_name,
    member->>'avatar_url' as avatar_url,
    COALESCE((member->>'is_host')::boolean, false) as is_host,
    COALESCE((member->>'is_ready')::boolean, false) as is_ready,
    COALESCE((member->>'is_spectator')::boolean, false) as is_spectator,
    member->>'team' as team,
    r.created_at
FROM rooms r,
    jsonb_array_elements(r.members) as member
WHERE r.members IS NOT NULL 
AND jsonb_array_length(members) > 0
AND member->>'user_id' IS NOT NULL
AND member->>'user_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

-- Verify the migration
SELECT 
    rm.room_id,
    r.name as room_name,
    rm.user_id,
    rm.display_name,
    rm.is_host,
    rm.is_ready,
    rm.created_at as joined_at
FROM room_members rm
JOIN rooms r ON rm.room_id = r.id
ORDER BY rm.room_id, rm.is_host DESC;

-- Check for any rooms that might not have been migrated
SELECT 
    id, 
    name, 
    members,
    'Not migrated' as status
FROM rooms 
WHERE id NOT IN (SELECT DISTINCT room_id FROM room_members)
AND members IS NOT NULL 
AND jsonb_array_length(members) > 0;

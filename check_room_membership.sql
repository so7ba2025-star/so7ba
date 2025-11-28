-- First, let's see some example data to understand the format
-- List some rooms
SELECT id, name, host_id, status, created_at 
FROM rooms 
ORDER BY created_at DESC 
LIMIT 5;

-- List some users
SELECT id, email, created_at 
FROM auth.users 
ORDER BY created_at DESC 
LIMIT 5;

-- Example 1: Check if a specific user is a member of a specific room
-- Replace the UUIDs with actual values from the above queries
SELECT EXISTS (
    SELECT 1 
    FROM room_members 
    WHERE room_id = '00000000-0000-0000-0000-000000000000' -- Replace with actual room_id
    AND user_id = '00000000-0000-0000-0000-000000000000'  -- Replace with actual user_id
) AS is_member;

-- Example 2: Get all rooms where a specific user is a member
-- Replace the user_id with an actual user ID
SELECT r.id, r.name, r.status, r.created_at
FROM rooms r
JOIN room_members rm ON r.id = rm.room_id
WHERE rm.user_id = '00000000-0000-0000-0000-000000000000'  -- Replace with actual user_id
ORDER BY r.created_at DESC;

-- Example 3: Get all members of a specific room
-- Replace the room_id with an actual room ID
SELECT 
    u.id,
    u.email,
    rm.is_host,
    rm.is_ready,
    rm.is_spectator,
    rm.team,
    rm.created_at as joined_at
FROM room_members rm
JOIN auth.users u ON rm.user_id = u.id
WHERE rm.room_id = '00000000-0000-0000-0000-000000000000'  -- Replace with actual room_id
ORDER BY rm.is_host DESC, rm.created_at;

-- Example 4: Check if user is a member and get their role in the room
-- Replace both IDs with actual values
SELECT 
    u.id,
    u.email,
    rm.is_host,
    rm.is_ready,
    rm.is_spectator,
    rm.team,
    rm.created_at as joined_at
FROM auth.users u
JOIN room_members rm ON u.id = rm.user_id
WHERE u.id = '00000000-0000-0000-0000-000000000000'       -- Replace with actual user_id
AND rm.room_id = '00000000-0000-0000-0000-000000000000';  -- Replace with actual room_id

-- Check room members for the test room
SELECT 
    rm.user_id,
    rm.display_name,
    rm.avatar_url,
    rm.is_host,
    rm.is_ready,
    rm.is_spectator,
    rm.team,
    up.first_name,
    up.last_name,
    up.email
FROM room_members rm
LEFT JOIN user_profiles up ON rm.user_id = up.id
WHERE rm.room_id = 'room_1762458950918_376'
ORDER BY rm.created_at ASC;

-- Also check the room data
SELECT 
    id,
    name,
    host_id,
    status,
    created_at
FROM rooms 
WHERE id = 'room_1762458950918_376';

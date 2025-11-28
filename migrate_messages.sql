-- Migrate existing messages from JSONB to room_messages table

-- First, let's see what messages we have
SELECT 
    id, 
    name, 
    messages,
    jsonb_array_length(messages) as message_count
FROM rooms 
WHERE messages IS NOT NULL 
AND jsonb_array_length(messages) > 0;

-- Check the structure of message data
SELECT 
    r.id,
    message,
    message->>'images' as images_text,
    message->>'animated_images' as animated_images_text
FROM rooms r,
    jsonb_array_elements(r.messages) as message
WHERE r.messages IS NOT NULL 
AND jsonb_array_length(r.messages) > 0
LIMIT 5;

-- Check for duplicate message IDs
SELECT 
    message->>'id' as message_id,
    COUNT(*) as duplicate_count
FROM rooms r,
    jsonb_array_elements(r.messages) as message
WHERE r.messages IS NOT NULL 
AND jsonb_array_length(r.messages) > 0
AND message->>'id' IS NOT NULL
GROUP BY message->>'id'
HAVING COUNT(*) > 1;

-- Now migrate the data with DISTINCT to avoid duplicates
INSERT INTO room_messages (
    id,
    room_id,
    user_id,
    display_name,
    content,
    sent_at,
    is_system,
    avatar_url,
    emoji,
    images,
    animated_images
)
SELECT DISTINCT ON (message->>'id')
    message->>'id' as id,
    r.id as room_id,
    CASE 
        WHEN message->>'user_id' != 'system' AND message->>'user_id' ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        THEN (message->>'user_id')::uuid
        ELSE NULL
    END as user_id,
    message->>'display_name' as display_name,
    message->>'content' as content,
    (message->>'sent_at')::timestamp with time zone as sent_at,
    COALESCE((message->>'is_system')::boolean, false) as is_system,
    message->>'avatar_url' as avatar_url,
    message->>'emoji' as emoji,
    CASE 
        WHEN message->>'images' IS NOT NULL AND jsonb_typeof(message->'images') = 'array'
        THEN ARRAY(SELECT jsonb_array_elements_text(message->'images'))
        ELSE NULL
    END as images,
    CASE 
        WHEN message->>'animated_images' IS NOT NULL AND jsonb_typeof(message->'animated_images') = 'array'
        THEN ARRAY(SELECT jsonb_array_elements_text(message->'animated_images'))
        ELSE NULL
    END as animated_images
FROM rooms r,
    jsonb_array_elements(r.messages) as message
WHERE r.messages IS NOT NULL 
AND jsonb_array_length(r.messages) > 0
AND message->>'id' IS NOT NULL;

-- Verify the migration
SELECT 
    rm.room_id,
    r.name as room_name,
    rm.id as message_id,
    rm.display_name,
    rm.content,
    rm.sent_at,
    rm.is_system,
    rm.images,
    rm.animated_images
FROM room_messages rm
JOIN rooms r ON rm.room_id = r.id
ORDER BY rm.room_id, rm.sent_at ASC
LIMIT 10;

-- Count messages per room
SELECT 
    rm.room_id,
    r.name as room_name,
    COUNT(*) as message_count
FROM room_messages rm
JOIN rooms r ON rm.room_id = r.id
GROUP BY rm.room_id, r.name
ORDER BY message_count DESC;

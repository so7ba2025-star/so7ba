-- استعرض كل الرسائل في جميع الغرف
SELECT 
    room_id,
    id as message_id,
    content,
    display_name,
    user_id,
    sent_at,
    is_system,
    avatar_url,
    emoji
FROM rooms, 
jsonb_array_elements(messages) as msg
ORDER BY room_id, sent_at;

-- استعرض رسائل غرفة معينة (استبدل room_id بالغرفة المطلوبة)
SELECT 
    id as message_id,
    content,
    display_name,
    user_id,
    sent_at,
    is_system,
    avatar_url,
    emoji
FROM rooms,
jsonb_array_elements(messages) as msg
WHERE room_id = 'room_1762458950918_376'
ORDER BY sent_at;

-- استعرض عدد الرسائل في كل غرفة
SELECT 
    room_id,
    name as room_name,
    jsonb_array_length(messages) as message_count
FROM rooms
ORDER BY message_count DESC;

-- استعرض آخر رسالة في كل غرفة
SELECT 
    room_id,
    name as room_name,
    (msg->>'content') as last_message,
    (msg->>'display_name') as last_sender,
    (msg->>'sent_at') as last_message_time
FROM rooms,
LATERAL (
    SELECT messages[jsonb_array_length(messages) - 1] as msg
) as last_msg
WHERE jsonb_array_length(messages) > 0
ORDER BY last_message_time DESC;

-- استعرض رسائل مستخدم معين (استبدل user_id بالمستخدم المطلوب)
SELECT 
    room_id,
    id as message_id,
    content,
    sent_at,
    display_name
FROM rooms,
jsonb_array_elements(messages) as msg
WHERE (msg->>'user_id')::uuid = '1b571f27-4010-4f6a-995c-df841f0ed683'::uuid
ORDER BY sent_at DESC;

-- استعرض الرسائل التي تحتوي على نص معين
SELECT 
    room_id,
    id as message_id,
    content,
    display_name,
    sent_at
FROM rooms,
jsonb_array_elements(messages) as msg
WHERE msg->>'content' ILIKE '%F%'
ORDER BY sent_at DESC;

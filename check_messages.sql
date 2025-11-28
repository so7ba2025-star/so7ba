-- استعلام لرؤية هيكل جدول rooms
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'rooms';

-- استعلام لرؤية عدد الرسائل في كل غرفة
SELECT 
    id as room_id,
    jsonb_array_length(messages) as message_count
FROM 
    rooms
WHERE 
    id = 'room_1762458950918_376'; -- استبدل بمعرف الغرفة الفعلي

-- استعلام لرؤية محتوى الرسائل في الغرفة
SELECT 
    id as room_id,
    jsonb_array_elements(messages)->>'id' as message_id,
    jsonb_array_elements(messages)->>'content' as content,
    jsonb_array_elements(messages)->>'user_id' as user_id,
    jsonb_array_elements(messages)->>'sent_at' as sent_at,
    (jsonb_array_elements(messages)->>'is_system')::boolean as is_system
FROM 
    rooms
WHERE 
    id = 'room_1762458950918_376' -- استبدل بمعرف الغرفة الفعلي
ORDER BY 
    sent_at DESC; -- ترتيب من الأحدث إلى الأقدم

-- استعلام لرؤية عدد الرسائل لكل مستخدم في الغرفة
SELECT 
    jsonb_array_elements(messages)->>'user_id' as user_id,
    COUNT(*) as message_count
FROM 
    rooms,
    jsonb_array_elements(messages)
WHERE 
    id = 'room_1762458950918_376' -- استبدل بمعرف الغرفة الفعلي
GROUP BY 
    jsonb_array_elements(messages)->>'user_id';

-- استعلام لرؤية إحصائيات الرسائل
SELECT 
    COUNT(*) as total_messages,
    COUNT(DISTINCT message->>'user_id') as unique_users,
    MIN((message->>'sent_at')::timestamp) as first_message_time,
    MAX((message->>'sent_at')::timestamp) as last_message_time
FROM 
    rooms,
    jsonb_array_elements(rooms.messages) as message
WHERE 
    id = 'room_1762458950918_376';

-- استعلام لرؤية توزيع الرسائل حسب النوع
SELECT 
    (message->>'is_system')::boolean as is_system,
    COUNT(*) as message_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM rooms, jsonb_array_elements(rooms.messages) as m WHERE id = 'room_1762458950918_376'), 2) as percentage
FROM 
    rooms,
    jsonb_array_elements(rooms.messages) as message
WHERE 
    id = 'room_1762458950918_376'
GROUP BY 
    (message->>'is_system')::boolean;

-- استعلام لرؤية آخر 50 رسالة في الغرفة مع المزيد من التفاصيل
WITH messages AS (
    SELECT 
        jsonb_array_elements(messages) as message
    FROM 
        rooms
    WHERE 
        id = 'room_1762458950918_376' -- استبدل بمعرف الغرفة الفعلي
)
SELECT 
    (message->>'sent_at')::timestamp as sent_at,
    message->>'id' as message_id,
    message->>'content' as content,
    message->>'user_id' as user_id,
    message->>'display_name' as display_name,
    (message->>'is_system')::boolean as is_system,
    CASE 
        WHEN (message->>'user_id') = '1b571f27-4010-4f6a-995c-df841f0ed683' THEN 'Current User' 
        ELSE 'Other User' 
    END as user_type,
    message->>'avatar_url' as avatar_url
FROM 
    messages
ORDER BY 
    (message->>'sent_at')::timestamp DESC
LIMIT 50;

-- استعلام لرؤية عدد الرسائل لكل نوع (نظامي / عادي)
SELECT 
    CASE 
        WHEN (message->>'is_system')::boolean THEN 'System Message' 
        ELSE 'User Message' 
    END as message_type,
    COUNT(*) as count
FROM 
    rooms,
    jsonb_array_elements(rooms.messages) as message
WHERE 
    id = 'room_1762458950918_376'
GROUP BY 
    (message->>'is_system')::boolean
ORDER BY 
    count DESC;

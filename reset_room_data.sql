-- Reset all room data (messages and members)
-- This will delete all messages and room members to start fresh

-- Delete all messages from room_messages table
DELETE FROM room_messages;

-- Delete all room members
DELETE FROM room_members;

-- Clear messages from rooms table (JSONB column)
UPDATE rooms SET messages = '[]'::jsonb;

-- Reset room updated_at to current time
UPDATE rooms SET updated_at = NOW();

-- Verify the reset
SELECT 
    'room_messages' as table_name, COUNT(*) as count 
FROM room_messages
UNION ALL
SELECT 
    'room_members' as table_name, COUNT(*) as count 
FROM room_members
UNION ALL
SELECT 
    'rooms_jsonb_messages' as table_name, 
    CASE 
        WHEN messages IS NULL OR jsonb_array_length(messages) = 0 THEN 0 
        ELSE jsonb_array_length(messages) 
    END as count 
FROM rooms;

-- Success message
SELECT 'All room data has been reset successfully!' as status;
SELECT 'Tables cleared: room_messages, room_members, rooms.messages' as details;
SELECT 'You can now start with fresh test data.' as next_step;

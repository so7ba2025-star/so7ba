-- Insert test messages with proper chronological order
-- This will create sample messages for testing

-- Test room ID (replace with your actual room ID)
-- You may need to change this to match your actual room ID
INSERT INTO room_messages (id, room_id, user_id, display_name, content, sent_at, is_system, avatar_url, emoji, images, animated_images) VALUES
-- Message 1: Early morning
('test_msg_001', 'room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'صباح الخير جميعاً', '2025-11-07 08:00:00', false, NULL, NULL, NULL, NULL),

-- Message 2: Response
('test_msg_002', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'صباح النور يا تامر', '2025-11-07 08:05:00', false, NULL, NULL, NULL, NULL),

-- Message 3: Another user joins
('test_msg_003', 'room_1762458950918_376', '676db6e2-e6ef-4935-8397-ed5bbcff3b71', 'عمرو عجاج', 'أهلاً بالجميع', '2025-11-07 08:10:00', false, NULL, NULL, NULL, NULL),

-- Message 4: System message
('test_msg_004', 'room_1762458950918_376', '00000000-0000-0000-0000-000000000000', 'System', 'عمرو عجاج انضم إلى الغرفة', '2025-11-07 08:10:01', true, NULL, NULL, NULL, NULL),

-- Message 5: Mid-morning chat
('test_msg_005', 'room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'كيف الحال يا عمرو؟', '2025-11-07 10:30:00', false, NULL, NULL, NULL, NULL),

-- Message 6: Response
('test_msg_006', 'room_1762458950918_376', '676db6e2-e6ef-4935-8397-ed5bbcff3b71', 'عمرو عجاج', 'الحمد لله، وأنت يا تامر؟', '2025-11-07 10:31:00', false, NULL, NULL, NULL, NULL),

-- Message 7: Ashraf joins
('test_msg_007', 'room_1762458950918_376', '58eda72d-aee0-48ba-ac42-547d8169e59d', 'Ashraf Abo Hamda', 'السلام عليكم', '2025-11-07 12:00:00', false, NULL, NULL, NULL, NULL),

-- Message 8: Welcome message
('test_msg_008', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'وعليكم السلام يا أشرف', '2025-11-07 12:01:00', false, NULL, NULL, NULL, NULL),

-- Message 9: Afternoon discussion
('test_msg_009', 'room_1762458950918_376', 'ecead5d2-56da-4abd-8dbd-0bb9f439d9e0', 'يوسف النجار', 'مرحباً يا جماعة، عندي سؤال', '2025-11-07 14:00:00', false, NULL, NULL, NULL, NULL),

-- Message 10: Question
('test_msg_010', 'room_1762458950918_376', 'ecead5d2-56da-4abd-8dbd-0bb9f439d9e0', 'يوسف النجار', 'متى موعد الاجتماع القادم؟', '2025-11-07 14:01:00', false, NULL, NULL, NULL, NULL),

-- Message 11: Host response
('test_msg_011', 'room_1762458950918_376', '01aa4a6e-c568-4dfb-8e5f-f389e5c6e399', 'tamer mohed', 'الاجتماع بكرة الساعة 3 عصراً', '2025-11-07 14:05:00', false, NULL, NULL, NULL, NULL),

-- Message 12: Confirmation
('test_msg_012', 'room_1762458950918_376', '58eda72d-aee0-48ba-ac42-547d8169e59d', 'Ashraf Abo Hamda', 'تمام، سأكون موجود', '2025-11-07 14:10:00', false, NULL, NULL, NULL, NULL),

-- Message 13: Late afternoon
('test_msg_013', 'room_1762458950918_376', '1b571f27-4010-4f6a-995c-df841f0ed683', 'اشرف محمود', 'وأنا أيضاً إن شاء الله', '2025-11-07 16:00:00', false, NULL, NULL, NULL, NULL),

-- Message 14: Final message
('test_msg_014', 'room_1762458950918_376', '676db6e2-e6ef-4935-8397-ed5bbcff3b71', 'عمرو عجاج', 'نشوفكم بكرة يا شباب', '2025-11-07 17:30:00', false, NULL, NULL, NULL, NULL);

-- Verify the inserted messages
SELECT 
    id,
    display_name,
    content,
    sent_at,
    EXTRACT(EPOCH FROM sent_at) as timestamp_seconds
FROM room_messages 
WHERE room_id = 'room_1762458950918_376'
ORDER BY sent_at ASC;

-- Success messages
SELECT 'Test messages inserted successfully!' as status;
SELECT 'Messages are in chronological order from 08:00 to 17:30' as details;
